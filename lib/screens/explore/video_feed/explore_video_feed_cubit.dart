import 'dart:async';

import 'package:beat_that/bloc/pooled_feed_playback.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/explore_feed_progress_store.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'explore_video_feed_presentation_event.dart';
import 'explore_video_feed_state.dart';

class ExploreVideoFeedCubit extends Cubit<ExploreVideoFeedState>
    with
        BlocPresentationMixin<
          ExploreVideoFeedState,
          ExploreVideoFeedPresentationEvent
        >,
        PooledFeedPlayback<ExploreVideoFeedState> {
  static const int _loadMoreThreshold = 3;
  static const int _continuationPageSize = 20;

  ExploreVideoFeedCubit({
    required List<SportVideo> initialVideos,
    required int initialIndex,
    required this.query,
    required this.nextOffset,
    required this.hasMoreContent,
    this.selectedSportId,
    this.isRandomFeed = false,
    this.randomSeed,
    this.randomAfterId,
    this.randomHasWrapped = false,
  }) : _supabaseService = locator<SupabaseService>(),
       _progressStore = locator<ExploreFeedProgressStore>(),
       super(
         ExploreVideoFeedState(
           videos: List<SportVideo>.from(initialVideos),
           currentIndex: initialIndex,
           nextOffset: nextOffset,
           hasMoreContent: hasMoreContent,
           isRandomFeed: isRandomFeed,
           randomSeed: randomSeed,
           randomAfterId: randomAfterId,
           randomHasWrapped: randomHasWrapped,
         ),
       );

  final SupabaseService _supabaseService;
  final ExploreFeedProgressStore _progressStore;
  final String query;
  final String? selectedSportId;
  final int nextOffset;
  final bool hasMoreContent;
  final bool isRandomFeed;
  final String? randomSeed;
  final String? randomAfterId;
  final bool randomHasWrapped;
  bool _isShuttingDown = false;

  Future<Map<String, dynamic>> _loadRandomExplorePage({
    String? seed,
    String? afterId,
    bool hasWrapped = false,
  }) async {
    final result = await _supabaseService.getRandomExploreVideos(
      limit: _continuationPageSize,
      seed: seed,
      afterId: afterId,
      hasWrapped: hasWrapped,
    );

    if (result['errorCode'] == '22023' && (afterId != null || hasWrapped)) {
      final resetResult = await _supabaseService.getRandomExploreVideos(
        limit: _continuationPageSize,
        seed: result['seed'] as String? ?? seed,
        afterId: null,
        hasWrapped: false,
      );

      final resetError = resetResult['error'] as String?;
      if (resetError != null && resetError.isNotEmpty) {
        throw Exception(resetError);
      }

      return resetResult;
    }

    final error = result['error'] as String?;
    if (error != null && error.isNotEmpty) {
      throw Exception(error);
    }

    return result;
  }

  @override
  List<SportVideo> get feedVideos => state.videos;

  @override
  int get feedCurrentIndex => state.currentIndex;

  bool get _isInactive => _isShuttingDown || isClosed;

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
    emit(
      state.copyWith(
        currentIndex: index,
        clearErrorMessage: true,
        currentUserRating: null,
      ),
    );
    _saveProgress();

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
        ExploreVideoFeedRatingErrorEvent(
          'This video cannot be rated right now.',
        ),
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
      final result = state.isRandomFeed
          ? await _loadRandomExplorePage(
              seed: state.randomSeed,
              afterId: state.randomAfterId,
              hasWrapped: state.randomHasWrapped,
            )
          : await _supabaseService.searchVideosByTitle(
              query,
              limit: _continuationPageSize,
              offset: state.nextOffset,
              sportId: selectedSportId,
            );
      if (_isInactive) return;

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
      final nextCursor = result['nextCursor'] as Map<String, dynamic>?;

      emit(
        state.copyWith(
          videos: [...state.videos, ...dedupedVideos],
          nextOffset: state.isRandomFeed
              ? state.nextOffset
              : result['nextOffset'] as int? ?? state.nextOffset,
          hasMoreContent: result['hasMore'] == true,
          randomSeed: state.isRandomFeed
              ? result['seed'] as String? ?? state.randomSeed
              : null,
          randomAfterId: state.isRandomFeed
              ? (nextCursor?['afterId'] as String?)
              : null,
          randomHasWrapped: state.isRandomFeed
              ? ((nextCursor?['hasWrapped']) == true)
              : false,
          isLoadingMore: false,
          clearErrorMessage: true,
        ),
      );

      _saveProgress();

      // Fill the preload window with the newly appended videos.
      updatePlaybackWindow();
    } catch (_) {
      if (_isInactive) return;
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

  int? _subcategoryIdForIndex(int index) {
    if (index < 0 || index >= state.videos.length) {
      return null;
    }

    return state.videos[index].subcategoryId;
  }

  void _saveProgress() {
    _progressStore.save(
      ExploreFeedProgress(
        query: query,
        selectedSportId: selectedSportId,
        isRandomFeed: state.isRandomFeed,
        videos: state.videos,
        currentIndex: state.currentIndex,
        nextOffset: state.nextOffset,
        hasMore: state.hasMoreContent,
        randomSeed: state.randomSeed,
        randomAfterId: state.randomAfterId,
        randomHasWrapped: state.randomHasWrapped,
      ),
    );
  }

  @override
  Future<void> close() async {
    _isShuttingDown = true;
    await stopPlayback();
    return super.close();
  }
}
