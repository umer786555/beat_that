import 'dart:async';
import 'dart:io';

import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import 'home_video_feed_state.dart';

class HomeVideoFeedCubit extends Cubit<HomeVideoFeedState> {
  HomeVideoFeedCubit({required this.sessionId, required int initialIndex})
    : _homeFeedService = locator<HomeFeedService>(),
      _sessionStore = locator<HomeVideoFeedSessionStore>(),
      _seenVideoIds = _requireSession(sessionId).seenVideoIds,
      super(
        HomeVideoFeedState(
          videos: List<Map<String, dynamic>>.from(
            _requireSession(sessionId).videos,
          ),
          currentIndex: initialIndex,
          nextOffset: _requireSession(sessionId).nextOffset,
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
  final HomeVideoFeedSessionStore _sessionStore;
  final Set<String> _seenVideoIds;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _controllerInitializers = {};

  VideoPlayerController? controllerFor(int index) => _controllers[index];

  Future<void> initialize() async {
    await _activateIndex(state.currentIndex);
    await _loadMoreIfNeeded(state.currentIndex);
  }

  Future<void> onPageChanged(int index) async {
    if (index < 0 || index >= state.videos.length) {
      return;
    }

    emit(state.copyWith(currentIndex: index, clearErrorMessage: true));

    await _activateIndex(index);
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
    }

    _bumpControllerGeneration();
  }

  Future<void> retryActiveVideo() async {
    final currentIndex = state.currentIndex;
    await _disposeControllerAt(currentIndex);
    emit(state.copyWith(clearErrorMessage: true));
    await _activateIndex(currentIndex);
  }

  Future<void> _activateIndex(int index) async {
    await _ensureController(index, autoplay: true);
    await _ensureController(index + 1);

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
      }
      return;
    }

    final existingInitializer = _controllerInitializers[index];
    if (existingInitializer != null) {
      await existingInitializer;
      final initializedController = _controllers[index];
      if (autoplay && initializedController != null) {
        await initializedController.play();
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
    final videoUrl = video['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      emit(state.copyWith(errorMessage: 'This video is unavailable.'));
      return;
    }

    final isNetworkUrl =
        videoUrl.startsWith('http://') || videoUrl.startsWith('https://');

    final controller = isNetworkUrl
        ? VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        : VideoPlayerController.file(File(videoUrl));

    try {
      await controller.initialize();
      await controller.setLooping(true);

      _controllers[index] = controller;
      if (autoplay && index == state.currentIndex) {
        await controller.play();
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
        offset: state.nextOffset,
        limit: _continuationPageSize,
      );

      final newVideos = List<Map<String, dynamic>>.from(
        result['videos'] as List<dynamic>,
      );
      final nextOffset = result['nextOffset'] as int;
      final hasMoreContent = result['hasMoreContent'] as bool;

      for (final video in newVideos) {
        final videoId = video['id'] as String?;
        if (videoId != null) {
          _seenVideoIds.add(videoId);
        }
      }

      emit(
        state.copyWith(
          videos: [...state.videos, ...newVideos],
          nextOffset: nextOffset,
          hasMoreContent: hasMoreContent,
          isLoadingMore: false,
          clearErrorMessage: true,
        ),
      );

      _sessionStore.appendVideos(
        sessionId: sessionId,
        videos: newVideos,
        nextOffset: nextOffset,
        hasMoreContent: hasMoreContent,
      );

      await _ensureController(state.currentIndex + 1);
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
    final controller = _controllers.remove(index);
    if (controller != null) {
      await controller.dispose();
      _bumpControllerGeneration();
    }
  }

  void _bumpControllerGeneration() {
    emit(state.copyWith(controllerGeneration: state.controllerGeneration + 1));
  }

  @override
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.dispose();
    }
    _controllers.clear();
    _controllerInitializers.clear();
    _sessionStore.removeSession(sessionId);
    return super.close();
  }
}
