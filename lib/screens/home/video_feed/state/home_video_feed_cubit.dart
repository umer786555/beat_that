import 'dart:async';

import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../presentation/events/home_video_feed_presentation_event.dart';
import 'home_video_feed_state.dart';

class HomeVideoFeedCubit extends Cubit<HomeVideoFeedState>
    with
        BlocPresentationMixin<
          HomeVideoFeedState,
          HomeVideoFeedPresentationEvent
        > {
  static const Duration _viewCountThreshold = Duration(seconds: 8);
  static const Duration _replayResetThreshold = Duration(milliseconds: 600);

  HomeVideoFeedCubit({required this.sessionId, required int initialIndex})
    : _homeFeedService = locator<HomeFeedService>(),
      _supabaseService = locator<SupabaseService>(),
      _sessionStore = locator<HomeVideoFeedSessionStore>(),
      _seenVideoIds = _requireSession(sessionId).seenVideoIds,
      super(
        HomeVideoFeedState(
          videos: List<SportVideo>.from(
            _requireSession(sessionId).videos,
          ),
          currentIndex: initialIndex,
          nextCursor: _requireSession(sessionId).nextCursor,
          hasMoreContent: _requireSession(sessionId).hasMoreContent,
        ),
      );

  static HomeVideoFeedSession _requireSession(String sessionId) {
    final session = locator<HomeVideoFeedSessionStore>().getSession(sessionId);
    if (session == null) {
      throw StateError('Missing home video feed session: $sessionId');
    }
    return session;
  }

  static const int _loadMoreThreshold = 3;
  static const int _continuationPageSize = 20;

  final String sessionId;
  final HomeFeedService _homeFeedService;
  final SupabaseService _supabaseService;
  final HomeVideoFeedSessionStore _sessionStore;
  final Set<String> _seenVideoIds;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _controllerInitializers = {};
  final Map<int, void Function()> _controllerListeners = {};
  final Set<int> _viewThresholdReachedIndexes = {};

  VideoPlayerController? controllerFor(int index) => _controllers[index];

  Future<void> initialize() async {
    await _activateIndex(state.currentIndex);
    await _loadUserRatingForIndex(state.currentIndex);
    await _loadMoreIfNeeded(state.currentIndex);
  }

  Future<void> onPageChanged(int index) async {
    if (index < 0 || index >= state.videos.length) {
      return;
    }

    emit(
      state.copyWith(
        currentIndex: index,
        clearErrorMessage: true,
        currentUserRating: null,
      ),
    );

    await _activateIndex(index);
    await _loadUserRatingForIndex(index);
    await _loadMoreIfNeeded(index);
  }

  Future<void> togglePlayback(int index) async {
    final controller = _controllers[index];
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await _pauseAllExcept(index);
      await controller.play();
      _trackViewProgress(index);
    }

    _bumpControllerGeneration();
  }

  Future<void> retryActiveVideo() async {
    final currentIndex = state.currentIndex;
    await _disposeControllerAt(currentIndex);
    emit(state.copyWith(clearErrorMessage: true));
    await _activateIndex(currentIndex);
  }

  String? reportVideoIdForIndex(int index) => _videoIdForIndex(index);

  Future<bool> submitRating(int rating) async {
    final videoId = _videoIdForIndex(state.currentIndex);
    if (videoId == null || videoId.isEmpty) {
      emitPresentation(
        HomeVideoFeedRatingErrorEvent('This video cannot be rated right now.'),
      );
      return false;
    }

    emit(state.copyWith(isSubmittingRating: true));

    final result = await _supabaseService.rateVideo(
      videoId: videoId,
      rating: rating,
    );

    if (result['success'] == true) {
      emit(
        state.copyWith(currentUserRating: rating, isSubmittingRating: false),
      );
      emitPresentation(
        HomeVideoFeedRatingSuccessEvent(
          'Your $rating/10 rating has been added.',
        ),
      );
      return true;
    }

    emit(state.copyWith(isSubmittingRating: false));
    emitPresentation(
      HomeVideoFeedRatingErrorEvent(
        result['error'] as String? ?? 'Could not submit your rating.',
      ),
    );
    return false;
  }

  Future<void> _activateIndex(int index) async {
    await _ensureController(index, autoplay: true);

    await _disposeStaleControllers(index);

    await _pauseAllExcept(index);
    _bumpControllerGeneration();
  }

  Future<void> _ensureController(int index, {bool autoplay = false}) async {
    if (index < 0 || index >= state.videos.length) {
      return;
    }

    final existingController = _controllers[index];
    if (existingController != null) {
      if (autoplay) {
        await existingController.play();
        _trackViewProgress(index);
      }
      return;
    }

    final existingInitializer = _controllerInitializers[index];
    if (existingInitializer != null) {
      await existingInitializer;
      final initializedController = _controllers[index];
      if (autoplay && initializedController != null) {
        await initializedController.play();
        _trackViewProgress(index);
        _bumpControllerGeneration();
      }
      return;
    }

    final initializer = _initializeController(index, autoplay: autoplay);
    _controllerInitializers[index] = initializer;

    try {
      await initializer;
    } finally {
      _controllerInitializers.remove(index);
    }
  }

  Future<void> _initializeController(int index, {bool autoplay = false}) async {
    final video = state.videos[index];
    final videoSource = video.videoPath;
    if (videoSource.isEmpty) {
      emit(state.copyWith(errorMessage: 'This video is unavailable.'));
      return;
    }

    final isNetworkUrl =
        videoSource.startsWith('http://') || videoSource.startsWith('https://');

    late final VideoPlayerController controller;
    if (isNetworkUrl) {
      controller = VideoPlayerController.networkUrl(Uri.parse(videoSource));
    } else {
      final playbackUrl = await _supabaseService.resolveVideoPlaybackUrl(
        videoSource,
      );
      controller = VideoPlayerController.networkUrl(Uri.parse(playbackUrl));
    }

    try {
      await controller.initialize();
      await controller.setLooping(true);

      _controllers[index] = controller;
      _attachViewTrackingListener(index, controller);
      if (autoplay && index == state.currentIndex) {
        await controller.play();
        _trackViewProgress(index);
      }

      _bumpControllerGeneration();
    } catch (_) {
      await controller.dispose();
      if (index == state.currentIndex) {
        emit(
          state.copyWith(errorMessage: 'Failed to load video. Tap to retry.'),
        );
      }
    }
  }

  Future<void> _loadUserRatingForIndex(int index) async {
    final videoId = _videoIdForIndex(index);
    if (videoId == null || videoId.isEmpty) {
      emit(state.copyWith(currentUserRating: null));
      return;
    }

    final userRating = await _supabaseService.getUserRating(videoId: videoId);
    final currentUserRating = userRating?.rating;

    emit(state.copyWith(currentUserRating: currentUserRating));
  }

  String? _videoIdForIndex(int index) {
    if (index < 0 || index >= state.videos.length) {
      return null;
    }

    final videoId = state.videos[index].ratingTargetId;

    if (videoId == null || videoId.isEmpty) {
      print('[HOME_FEED_RATING] ❌ videoId is null or empty!');
    }

    return videoId;
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (!state.hasMoreContent || state.isLoadingMore) {
      return;
    }

    final remainingItems = state.videos.length - index - 1;
    if (remainingItems > _loadMoreThreshold) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true, clearErrorMessage: true));

    try {
      final result = await _homeFeedService.getHomeFeedContinuation(
        seenVideoIds: _seenVideoIds,
        cursor: state.nextCursor,
        limit: _continuationPageSize,
      );

      final newVideos = List<SportVideo>.from(
        result['videos'] as List<dynamic>,
      );
      final nextCursor = result['nextCursor'] as HomeFeedCursor;
      final hasMoreContent = result['hasMoreContent'] as bool;

      for (final video in newVideos) {
        _seenVideoIds.add(video.id);
      }

      emit(
        state.copyWith(
          videos: [...state.videos, ...newVideos],
          nextCursor: nextCursor,
          hasMoreContent: hasMoreContent,
          isLoadingMore: false,
          clearErrorMessage: true,
        ),
      );

      _sessionStore.appendVideos(
        sessionId: sessionId,
        videos: newVideos,
        nextCursor: nextCursor,
        hasMoreContent: hasMoreContent,
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: 'Failed to load more videos.',
        ),
      );
    }
  }

  Future<void> _pauseAllExcept(int activeIndex) async {
    for (final entry in _controllers.entries) {
      if (entry.key == activeIndex) {
        continue;
      }

      if (entry.value.value.isPlaying) {
        await entry.value.pause();
      }
    }
  }

  Future<void> _disposeStaleControllers(int activeIndex) async {
    final staleIndexes = _controllers.keys
        .where((index) => index != activeIndex && index != activeIndex + 1)
        .toList();

    for (final index in staleIndexes) {
      await _disposeControllerAt(index);
    }
  }

  Future<void> _disposeControllerAt(int index) async {
    _detachViewTrackingListener(index);
    final controller = _controllers.remove(index);
    if (controller != null) {
      await controller.dispose();
      _bumpControllerGeneration();
    }
  }

  void _attachViewTrackingListener(
    int index,
    VideoPlayerController controller,
  ) {
    if (_controllerListeners.containsKey(index)) {
      return;
    }

    void listener() {
      _trackViewProgress(index);
    }

    _controllerListeners[index] = listener;
    controller.addListener(listener);
  }

  void _detachViewTrackingListener(int index) {
    final listener = _controllerListeners.remove(index);
    final controller = _controllers[index];
    if (listener != null && controller != null) {
      controller.removeListener(listener);
    }

    _viewThresholdReachedIndexes.remove(index);
  }

  void _trackViewProgress(int index) {
    if (index != state.currentIndex) {
      return;
    }

    final controller = _controllers[index];
    if (controller == null) {
      return;
    }

    final value = controller.value;
    if (!value.isInitialized) {
      return;
    }

    if (value.position <= _replayResetThreshold) {
      _viewThresholdReachedIndexes.remove(index);
    }

    if (!value.isPlaying) {
      return;
    }

    if (_viewThresholdReachedIndexes.contains(index)) {
      return;
    }

    if (value.position < _viewCountThreshold) {
      return;
    }

    _viewThresholdReachedIndexes.add(index);
    unawaited(_incrementViewCount(index));
  }

  Future<void> _incrementViewCount(int index) async {
    final linkedVideoId = _linkedVideoIdForIndex(index);
    if (linkedVideoId == null || linkedVideoId.isEmpty) {
      print(
        '⚠️ HomeVideoFeedCubit: Skipping view count update because linked video id is missing for index $index',
      );
      return;
    }

    try {
      final result = await _supabaseService.updateCategoryVideoViewCount(
        linkedVideoId: linkedVideoId,
      );

      if (result['success'] == true) {
        print(
          '✅ HomeVideoFeedCubit: View count updated for linkedVideoId=$linkedVideoId',
        );
        return;
      }

      print(
        '⚠️ HomeVideoFeedCubit: View count update failed for linkedVideoId=$linkedVideoId. Error: ${result['error']}',
      );
    } catch (e) {
      print(
        '⚠️ HomeVideoFeedCubit: View count update threw unexpectedly for linkedVideoId=$linkedVideoId. Error: $e',
      );
    }
  }

  String? _linkedVideoIdForIndex(int index) {
    if (index < 0 || index >= state.videos.length) {
      return null;
    }

    return state.videos[index].id;
  }

  void _bumpControllerGeneration() {
    emit(state.copyWith(controllerGeneration: state.controllerGeneration + 1));
  }

  @override
  Future<void> close() async {
    for (final entry in _controllerListeners.entries) {
      final controller = _controllers[entry.key];
      if (controller != null) {
        controller.removeListener(entry.value);
      }
    }
    _controllerListeners.clear();
    _viewThresholdReachedIndexes.clear();
    for (final controller in _controllers.values) {
      await controller.dispose();
    }
    _controllers.clear();
    _controllerInitializers.clear();
    _sessionStore.removeSession(sessionId);
    return super.close();
  }
}
