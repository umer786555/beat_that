import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'explore_event.dart';
part 'explore_state.dart';

enum ExploreSearchMode { soft, startsWith, exact }

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  static const int _pageSize = 20;

  ExploreBloc()
    : _supabaseService = locator<SupabaseService>(),
      super(const ExploreInitial()) {
    on<SearchExploreVideosEvent>(_onSearchExploreVideos);
    on<LoadMoreExploreVideosEvent>(_onLoadMoreExploreVideos);
    on<RefreshExploreVideosEvent>(_onRefreshExploreVideos);
    on<RetryExploreSearchEvent>(_onRetryExploreSearch);
  }

  final SupabaseService _supabaseService;

  Future<void> _onSearchExploreVideos(
    SearchExploreVideosEvent event,
    Emitter<ExploreState> emit,
  ) async {
    final normalizedQuery = event.query.trim();
    final normalizedSportId = event.selectedSportId?.trim();
    final hasSportFilter =
        normalizedSportId != null && normalizedSportId.isNotEmpty;

    if (normalizedQuery.isEmpty && !hasSportFilter) {
      emit(const ExploreInitial());
      return;
    }

    emit(
      ExploreLoading(
        query: normalizedQuery,
        searchMode: event.searchMode,
        selectedSportId: normalizedSportId,
      ),
    );

    try {
      final result = await _supabaseService.searchVideosByTitle(
        normalizedQuery,
        limit: _pageSize,
        offset: 0,
        exactMatch: event.searchMode == ExploreSearchMode.exact,
        startsWithOnly: event.searchMode == ExploreSearchMode.startsWith,
        sportId: normalizedSportId,
      );

      emit(
        ExploreLoaded(
          query: normalizedQuery,
          searchMode: event.searchMode,
          selectedSportId: normalizedSportId,
          videos: List<Map<String, dynamic>>.from(
            result['videos'] as List<dynamic>? ?? const [],
          ),
          totalCount: result['totalCount'] as int? ?? 0,
          hasMore: result['hasMore'] == true,
          nextOffset: result['nextOffset'] as int? ?? 0,
        ),
      );
    } catch (e) {
      emit(
        ExploreError(
          message: 'Failed to search videos: $e',
          query: normalizedQuery,
          searchMode: event.searchMode,
          selectedSportId: normalizedSportId,
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
        !currentState.hasMore) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final result = await _supabaseService.searchVideosByTitle(
        currentState.query,
        limit: _pageSize,
        offset: currentState.nextOffset,
        exactMatch: currentState.searchMode == ExploreSearchMode.exact,
        startsWithOnly: currentState.searchMode == ExploreSearchMode.startsWith,
        sportId: currentState.selectedSportId,
      );

      final newVideos = List<Map<String, dynamic>>.from(
        result['videos'] as List<dynamic>? ?? const [],
      );
      final existingIds = currentState.videos
          .map((video) => video['id'] as String?)
          .whereType<String>()
          .toSet();
      final dedupedVideos = newVideos.where((video) {
        final videoId = video['id'] as String?;
        return videoId == null || !existingIds.contains(videoId);
      }).toList();

      emit(
        currentState.copyWith(
          videos: [...currentState.videos, ...dedupedVideos],
          totalCount: result['totalCount'] as int? ?? currentState.totalCount,
          hasMore: result['hasMore'] == true,
          nextOffset: result['nextOffset'] as int? ?? currentState.nextOffset,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(currentState.copyWith(isLoadingMore: false));
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
          searchMode: loadedState.searchMode,
          selectedSportId: loadedState.selectedSportId,
        ),
      );
      return;
    }

    if (currentState case ExploreError errorState) {
      add(
        SearchExploreVideosEvent(
          query: errorState.query,
          searchMode: errorState.searchMode,
          selectedSportId: errorState.selectedSportId,
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
          searchMode: currentState.searchMode,
          selectedSportId: currentState.selectedSportId,
        ),
      );
      return;
    }

    if (currentState is ExploreLoaded) {
      add(
        SearchExploreVideosEvent(
          query: currentState.query,
          searchMode: currentState.searchMode,
          selectedSportId: currentState.selectedSportId,
        ),
      );
    }
  }
}
