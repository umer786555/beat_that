import 'dart:async';
import 'dart:io';

import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'explore_video_feed_presentation_event.dart';
import 'explore_video_feed_state.dart';

class ExploreVideoFeedCubit extends Cubit<ExploreVideoFeedState>
    with
        BlocPresentationMixin<
          ExploreVideoFeedState,
          ExploreVideoFeedPresentationEvent
        > {
  static const Duration _viewCountThreshold = Duration(seconds: 8);
  static const Duration _replayResetThreshold = Duration(milliseconds: 600);
  static const int _loadMoreThreshold = 3;
  static const int _continuationPageSize = 20;

  ExploreVideoFeedCubit({
    required List<SportVideo> initialVideos,
    required int initialIndex,
    required this.query,
    required this.nextOffset,
    required this.hasMoreContent,
    this.selectedSportId,
  }) : _supabaseService = locator<SupabaseService>(),
       super(
         ExploreVideoFeedState(
           videos: List<SportVideo>.from(initialVideos),
           currentIndex: initialIndex,
           nextOffset: nextOffset,
           hasMoreContent: hasMoreContent,
         ),
       );

  final SupabaseService _supabaseService;
  final String query;
  final String? selectedSportId;
  final int nextOffset;
  final bool hasMoreContent;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _controllerInitializers = {};
  final Map<int, void Function()> _controllerListeners = {};
  final Set<int> _viewThresholdReachedIndexes = {};
  bool _isShuttingDown = false;

  VideoPlayerController? controllerFor(int index) => _controllers[index];

  bool get _isInactive => _isShuttingDown || isClosed;

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

  Future<bool> submitRating(int rating) async {
    final videoId = _videoIdForIndex(state.currentIndex);
    if (videoId == null || videoId.isEmpty) {
      emitPresentation(
        ExploreVideoFeedRatingErrorEvent(
          'This video cannot be rated right now.',
        ),
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
        ExploreVideoFeedRatingSuccessEvent(
          'Your $rating/10 rating has been added.',
        ),
      );
      return true;
    }

    emit(state.copyWith(isSubmittingRating: false));
    emitPresentation(
      ExploreVideoFeedRatingErrorEvent(
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
    if (_isInactive) {
      return;
    }

    if (index < 0 || index >= state.videos.length) {
      return;
    }

    final existingController = _controllers[index];
    if (existingController != null) {
      if (autoplay && !_isInactive) {
        await existingController.play();
        _trackViewProgress(index);
      }
      return;
    }

    final existingInitializer = _controllerInitializers[index];
    if (existingInitializer != null) {
      await existingInitializer;
      final initializedController = _controllers[index];
      if (autoplay && initializedController != null && !_isInactive) {
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
    if (_isInactive) {
      return;
    }

    final video = state.videos[index];
    final videoPath = video.videoPath;
    if (videoPath.isEmpty) {
      emit(state.copyWith(errorMessage: 'This video is unavailable.'));
      return;
    }

    final isNetworkUrl =
        videoPath.startsWith('http://') || videoPath.startsWith('https://');
    final localFile = File(videoPath);
    final isLocalFile = !isNetworkUrl && await localFile.exists();

    final controller = isNetworkUrl
        ? VideoPlayerController.networkUrl(Uri.parse(videoPath))
        : isLocalFile
        ? VideoPlayerController.file(localFile)
        : VideoPlayerController.networkUrl(
            Uri.parse(
              await _supabaseService.resolveVideoPlaybackUrl(videoPath),
            ),
          );

    try {
      await controller.initialize();

      if (_isInactive || index != state.currentIndex && autoplay) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);

      if (_isInactive) {
        await controller.dispose();
        return;
      }

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

    return state.videos[index].ratingTargetId;
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
      final result = await _supabaseService.searchVideosByTitle(
        query,
        limit: _continuationPageSize,
        offset: state.nextOffset,
        sportId: selectedSportId,
      );

      final newVideos = List<SportVideo>.from(
        result['videos'] as List<dynamic>? ?? const <SportVideo>[],
      );
      final existingIds = state.videos
          .map((video) => video.id)
          .whereType<String>()
          .toSet();
      final dedupedVideos = newVideos.where((video) {
        final videoId = video.id;
        return !existingIds.contains(videoId);
      }).toList();

      emit(
        state.copyWith(
          videos: [...state.videos, ...dedupedVideos],
          nextOffset: result['nextOffset'] as int? ?? state.nextOffset,
          hasMoreContent: result['hasMore'] == true,
          isLoadingMore: false,
          clearErrorMessage: true,
        ),
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
      return;
    }

    await _supabaseService.updateCategoryVideoViewCount(
      linkedVideoId: linkedVideoId,
    );
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
    _isShuttingDown = true;

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
    return super.close();
  }
}
