import 'dart:math';

import 'package:beat_that/service_locator.dart';
import 'package:beat_that/screens/explore/explore_filter_catalog.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/services/explore_feed_progress_store.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';

part 'explore_event.dart';
part 'explore_state.dart';

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  static const int _pageSize = 20;
  static const int minQueryLength = 3;
  static final Random _random = Random();

  ExploreBloc({Locale? locale})
    : _locale = locale,
      _supabaseService = locator<SupabaseService>(),
      super(
        ExploreInitial(filterCatalog: buildFallbackExploreFilterCatalog(locale)),
      ) {
    on<LoadExploreFiltersEvent>(_onLoadExploreFilters);
    on<SearchExploreVideosEvent>(_onSearchExploreVideos);
    on<LoadMoreExploreVideosEvent>(_onLoadMoreExploreVideos);
    on<RefreshExploreVideosEvent>(_onRefreshExploreVideos);
    on<RetryExploreSearchEvent>(_onRetryExploreSearch);
    on<MergeExploreFeedProgressEvent>(_onMergeExploreFeedProgress);
  }

  final Locale? _locale;
  final SupabaseService _supabaseService;

  /// Shorter queries can't use the trigram search indexes, so they browse instead.
  static String effectiveQuery(String query) {
    final trimmed = query.trim();
    return trimmed.length < minQueryLength ? '' : trimmed;
  }

  // Bumped by every search so responses from older, slower requests are dropped.
  int _searchGeneration = 0;

  bool _usesRandomFeed(String query, String? selectedFilterId) {
    // Empty query + no sport filter means browse mode, not search mode.
    return query.isEmpty && (selectedFilterId == null || selectedFilterId.isEmpty);
  }

  // Without a seed the RPC falls back to the date, giving everyone the same order all day.
  String _newBrowseSeed() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  Future<void> _onLoadExploreFilters(
    LoadExploreFiltersEvent event,
    Emitter<ExploreState> emit,
  ) async {
    try {
      final rows = await _supabaseService.getExploreFilters();
      if (rows.isEmpty) {
        return;
      }

      emit(
        _withFilterCatalog(
          state,
          buildExploreFilterCatalogFromRows(locale: _locale, rows: rows),
        ),
      );
    } catch (_) {
      // Keep the fallback catalog if backend category tables are unavailable.
    }
  }

  Future<Map<String, dynamic>> _loadRandomExplorePage({
    required String? seed,
    String? afterId,
    bool hasWrapped = false,
  }) async {
    final result = await _supabaseService.getRandomExploreVideos(
      limit: _pageSize,
      seed: seed,
      afterId: afterId,
      hasWrapped: hasWrapped,
    );

    if (result['errorCode'] == '22023' && (afterId != null || hasWrapped)) {
      // If a persisted/random route cursor goes stale, restart the same seeded
      // browse session from the top instead of leaving the explore feed stuck.
      final resetResult = await _supabaseService.getRandomExploreVideos(
        limit: _pageSize,
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

  Future<void> _onSearchExploreVideos(
    SearchExploreVideosEvent event,
    Emitter<ExploreState> emit,
  ) async {
    final normalizedQuery = effectiveQuery(event.query);
    final normalizedFilterId = event.selectedFilterId?.trim();
    final usesRandomFeed = _usesRandomFeed(normalizedQuery, normalizedFilterId);
    final generation = ++_searchGeneration;

    emit(
      ExploreLoading(
        filterCatalog: state.filterCatalog,
        query: normalizedQuery,
        selectedFilterId: normalizedFilterId,
      ),
    );

    try {
      final result = usesRandomFeed
          ? await _loadRandomExplorePage(seed: _newBrowseSeed())
          : await _supabaseService.searchVideosByTitle(
              normalizedQuery,
              limit: _pageSize,
              offset: 0,
              sportId: normalizedFilterId,
            );
      if (generation != _searchGeneration) return;
      final nextCursor = result['nextCursor'] as Map<String, dynamic>?;

      emit(
        ExploreLoaded(
          filterCatalog: state.filterCatalog,
          query: normalizedQuery,
          selectedFilterId: normalizedFilterId,
          videos: List<SportVideo>.from(
            result['videos'] as List<dynamic>? ?? const <SportVideo>[],
          ),
          totalCount: usesRandomFeed
              ? (result['videos'] as List<dynamic>? ?? const <dynamic>[]).length
              : result['totalCount'] as int? ?? 0,
          hasMore: result['hasMore'] == true,
            // Offset applies only to search-mode continuation. Random mode keeps
            // its own seed + cursor state in the dedicated random fields below.
          nextOffset: usesRandomFeed ? 0 : result['nextOffset'] as int? ?? 0,
          isRandomFeed: usesRandomFeed,
          randomSeed: result['seed'] as String?,
          randomAfterId: nextCursor?['afterId'] as String?,
          randomHasWrapped: nextCursor?['hasWrapped'] == true,
        ),
      );
    } catch (e) {
      if (generation != _searchGeneration) return;
      emit(
        ExploreError(
          filterCatalog: state.filterCatalog,
          message: 'Failed to search videos: $e',
          query: normalizedQuery,
          selectedFilterId: normalizedFilterId,
        ),
      );
    }
  }

  Future<void> _onLoadMoreExploreVideos(
    LoadMoreExploreVideosEvent event,
    Emitter<ExploreState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ExploreLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMore ||
        (currentState.loadMoreFailed && !event.isRetry)) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true, loadMoreFailed: false));
    final generation = _searchGeneration;

    try {
      final result = currentState.isRandomFeed
          ? await _loadRandomExplorePage(
              seed: currentState.randomSeed,
              afterId: currentState.randomAfterId,
              hasWrapped: currentState.randomHasWrapped,
            )
          : await _supabaseService.searchVideosByTitle(
              currentState.query,
              limit: _pageSize,
              offset: currentState.nextOffset,
              sportId: currentState.selectedFilterId,
            );
      if (generation != _searchGeneration) return;

      final newVideos = List<SportVideo>.from(
        result['videos'] as List<dynamic>? ?? const <SportVideo>[],
      );
      final existingIds = currentState.videos
          .map((video) => video.id)
          .whereType<String>()
          .toSet();
      final dedupedVideos = newVideos.where((video) {
        final videoId = video.id;
        return !existingIds.contains(videoId);
      }).toList();
      final nextCursor = result['nextCursor'] as Map<String, dynamic>?;

      emit(
        currentState.copyWith(
          videos: [...currentState.videos, ...dedupedVideos],
          totalCount: currentState.isRandomFeed
              ? currentState.totalCount + dedupedVideos.length
              : result['totalCount'] as int? ?? currentState.totalCount,
          hasMore: result['hasMore'] == true,
          nextOffset: currentState.isRandomFeed
              ? currentState.nextOffset
              : result['nextOffset'] as int? ?? currentState.nextOffset,
          isLoadingMore: false,
          loadMoreFailed: false,
          randomSeed: currentState.isRandomFeed
              ? result['seed'] as String? ?? currentState.randomSeed
              : null,
          randomAfterId: currentState.isRandomFeed
              ? (nextCursor?['afterId'] as String?)
              : null,
          randomHasWrapped: currentState.isRandomFeed
              ? ((nextCursor?['hasWrapped']) == true)
              : false,
        ),
      );
    } catch (_) {
      if (generation != _searchGeneration) return;
      emit(currentState.copyWith(isLoadingMore: false, loadMoreFailed: true));
    }
  }

  Future<void> _onRefreshExploreVideos(
    RefreshExploreVideosEvent event,
    Emitter<ExploreState> emit,
  ) async {
    final currentState = state;

    if (currentState case ExploreLoaded loadedState) {
      add(
        SearchExploreVideosEvent(
          query: loadedState.query,
          selectedFilterId: loadedState.selectedFilterId,
        ),
      );
      return;
    }

    if (currentState case ExploreError errorState) {
      add(
        SearchExploreVideosEvent(
          query: errorState.query,
          selectedFilterId: errorState.selectedFilterId,
        ),
      );
    }
  }

  Future<void> _onRetryExploreSearch(
    RetryExploreSearchEvent event,
    Emitter<ExploreState> emit,
  ) async {
    final currentState = state;
    if (currentState is ExploreError) {
      add(
        SearchExploreVideosEvent(
          query: currentState.query,
          selectedFilterId: currentState.selectedFilterId,
        ),
      );
      return;
    }

    if (currentState is ExploreLoaded) {
      add(
        SearchExploreVideosEvent(
          query: currentState.query,
          selectedFilterId: currentState.selectedFilterId,
        ),
      );
    }
  }

  void _onMergeExploreFeedProgress(
    MergeExploreFeedProgressEvent event,
    Emitter<ExploreState> emit,
  ) {
    final currentState = state;
    final progress = event.progress;
    if (currentState is! ExploreLoaded ||
        currentState.isLoadingMore ||
        progress.query != currentState.query ||
        progress.selectedSportId != currentState.selectedFilterId ||
        progress.isRandomFeed != currentState.isRandomFeed ||
        progress.randomSeed != currentState.randomSeed ||
        progress.videos.length <= currentState.videos.length) {
      return;
    }

    // Only extend the grid if the feed's list continues the grid's list exactly.
    for (var i = 0; i < currentState.videos.length; i++) {
      if (progress.videos[i].id != currentState.videos[i].id) return;
    }

    emit(
      currentState.copyWith(
        videos: List<SportVideo>.from(progress.videos),
        totalCount: currentState.isRandomFeed
            ? progress.videos.length
            : currentState.totalCount,
        hasMore: progress.hasMore,
        nextOffset: progress.nextOffset,
        loadMoreFailed: false,
        randomAfterId: progress.randomAfterId,
        randomHasWrapped: progress.randomHasWrapped,
      ),
    );
  }

  ExploreState _withFilterCatalog(
    ExploreState currentState,
    ExploreFilterCatalog filterCatalog,
  ) {
    if (currentState is ExploreLoaded) {
      return currentState.copyWith(filterCatalog: filterCatalog);
    }

    if (currentState is ExploreLoading) {
      return ExploreLoading(
        filterCatalog: filterCatalog,
        query: currentState.query,
        selectedFilterId: currentState.selectedFilterId,
      );
    }

    if (currentState is ExploreError) {
      return ExploreError(
        filterCatalog: filterCatalog,
        message: currentState.message,
        query: currentState.query,
        selectedFilterId: currentState.selectedFilterId,
      );
    }

    return ExploreInitial(
      filterCatalog: filterCatalog,
      selectedFilterId: currentState.selectedFilterId,
    );
  }
}
