import 'dart:async';

import 'package:beat_that/bloc/pooled_feed_playback.dart';
import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/events/home_video_feed_presentation_event.dart';
import 'home_video_feed_state.dart';

class HomeVideoFeedCubit extends Cubit<HomeVideoFeedState>
    with
        BlocPresentationMixin<
          HomeVideoFeedState,
          HomeVideoFeedPresentationEvent
        >,
        PooledFeedPlayback<HomeVideoFeedState> {
  HomeVideoFeedCubit({required this.sessionId, required int initialIndex})
    : _homeFeedService = locator<HomeFeedService>(),
      _supabaseService = locator<SupabaseService>(),
      _sessionStore = locator<HomeVideoFeedSessionStore>(),
      _seenVideoIds = _requireSession(sessionId).seenVideoIds,
      super(
        HomeVideoFeedState(
          videos: List<SportVideo>.from(_requireSession(sessionId).videos),
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

  @override
  List<SportVideo> get feedVideos => state.videos;

  @override
  int get feedCurrentIndex => state.currentIndex;

  Future<void> initialize() async {
    startPlayback();
    engagementTracker.startVideo(_subcategoryIdForIndex(state.currentIndex));
    _activateCurrentVideo();
    await _loadUserRatingForIndex(state.currentIndex);
    await _loadMoreIfNeeded(state.currentIndex);
  }

  Future<void> onPageChanged(int index) async {
    if (index < 0 || index >= state.videos.length) {
      return;
    }

    engagementTracker.startVideo(_subcategoryIdForIndex(index));
    _sessionStore.updateCurrentIndex(sessionId, index);
    emit(
      state.copyWith(
        currentIndex: index,
        clearErrorMessage: true,
        currentUserRating: null,
      ),
    );

    _activateCurrentVideo();
    await _loadUserRatingForIndex(index);
    await _loadMoreIfNeeded(index);
  }

  void retryActiveVideo() {
    final videoPath = state.videos[state.currentIndex].videoPath;
    if (videoPath.isEmpty) {
      return;
    }

    emit(state.copyWith(clearErrorMessage: true));
    retryPlayback(videoPath);
  }

  String? reportTargetIdForIndex(int index) => _ratingTargetIdForIndex(index);

  Future<bool> submitRating(int rating) async {
    final ratingTargetId = _ratingTargetIdForIndex(state.currentIndex);
    if (ratingTargetId == null || ratingTargetId.isEmpty) {
      emitPresentation(
        HomeVideoFeedRatingErrorEvent('This video cannot be rated right now.'),
      );
      return false;
    }

    emit(state.copyWith(isSubmittingRating: true));

    final result = await _supabaseService.rateVideo(
      videoId: ratingTargetId,
      rating: rating,
    );

    if (result['success'] == true) {
      engagementTracker.onRated(rating);
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

  void _activateCurrentVideo() {
    activatePlayback();

    final index = state.currentIndex;
    if (index >= 0 &&
        index < state.videos.length &&
        state.videos[index].videoPath.isEmpty) {
      emit(state.copyWith(errorMessage: 'This video is unavailable.'));
    }
  }

  Future<void> _loadUserRatingForIndex(int index) async {
    final ratingTargetId = _ratingTargetIdForIndex(index);
    if (ratingTargetId == null || ratingTargetId.isEmpty) {
      emit(state.copyWith(currentUserRating: null));
      return;
    }

    final userRating = await _supabaseService.getUserRating(
      videoId: ratingTargetId,
    );
    final currentUserRating = userRating?.rating;

    emit(state.copyWith(currentUserRating: currentUserRating));
  }

  String? _ratingTargetIdForIndex(int index) {
    if (index < 0 || index >= state.videos.length) {
      return null;
    }

    final ratingTargetId = state.videos[index].ratingTargetId;

    if (ratingTargetId == null || ratingTargetId.isEmpty) {
      debugPrint('[HOME_FEED_RATING] ratingTargetId is null or empty.');
    }

    return ratingTargetId;
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
        cursor: state.nextCursor,
        limit: _continuationPageSize,
      );
      if (isClosed) return;

      final newVideos = List<SportVideo>.from(
        result['videos'] as List<dynamic>,
      ).where((video) => !_seenVideoIds.contains(video.id)).toList();
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

      // Fill the preload window with the newly appended videos.
      updatePlaybackWindow();
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: 'Failed to load more videos.',
        ),
      );
    }
  }

  @override
  void onViewThresholdReached() {
    unawaited(_incrementViewCount(state.currentIndex));
  }

  Future<void> _incrementViewCount(int index) async {
    final linkedVideoId = _linkedVideoIdForIndex(index);

    if (linkedVideoId == null || linkedVideoId.isEmpty) {
      debugPrint(
        'HomeVideoFeedCubit: Skipping view count update because linked video id is missing for index $index',
      );
      return;
    }

    try {
      final result = await _supabaseService.updateCategoryVideoViewCount(
        linkedVideoId: linkedVideoId,
      );

      if (result['success'] == true) {
        debugPrint(
          'HomeVideoFeedCubit: View count updated for linkedVideoId=$linkedVideoId',
        );
        return;
      }

      debugPrint(
        'HomeVideoFeedCubit: View count update failed for linkedVideoId=$linkedVideoId. Error: ${result['error']}',
      );
    } catch (e) {
      debugPrint(
        'HomeVideoFeedCubit: View count update threw unexpectedly for linkedVideoId=$linkedVideoId. Error: $e',
      );
    }
  }

  String? _linkedVideoIdForIndex(int index) {
    if (index < 0 || index >= state.videos.length) {
      return null;
    }

    return state.videos[index].id;
  }

  int? _subcategoryIdForIndex(int index) {
    if (index < 0 || index >= state.videos.length) {
      return null;
    }

    return state.videos[index].subcategoryId;
  }

  @override
  Future<void> close() async {
    await stopPlayback();
    return super.close();
  }
}
