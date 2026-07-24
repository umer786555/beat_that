part of 'explore_bloc.dart';

sealed class ExploreState extends Equatable {
  const ExploreState();

  @override
  List<Object> get props => [];
}

final class ExploreInitial extends ExploreState {
  const ExploreInitial();
}

final class ExploreLoading extends ExploreState {
  const ExploreLoading({
    required this.query,
    required this.searchMode,
    this.selectedSportId,
  });

  final String query;
  final ExploreSearchMode searchMode;
  final String? selectedSportId;

  @override
  List<Object> get props => [query, searchMode, selectedSportId ?? ''];
}

final class ExploreLoaded extends ExploreState {
  const ExploreLoaded({
    required this.query,
    required this.searchMode,
    required this.videos,
    required this.totalCount,
    required this.hasMore,
    required this.nextOffset,
    this.selectedSportId,
    this.isLoadingMore = false,
  });

  final String query;
  final ExploreSearchMode searchMode;
  final String? selectedSportId;
  final List<Map<String, dynamic>> videos;
  final int totalCount;
  final bool hasMore;
  final int nextOffset;
  final bool isLoadingMore;

  ExploreLoaded copyWith({
    String? query,
    ExploreSearchMode? searchMode,
    String? selectedSportId,
    List<Map<String, dynamic>>? videos,
    int? totalCount,
    bool? hasMore,
    int? nextOffset,
    bool? isLoadingMore,
  }) {
    return ExploreLoaded(
      query: query ?? this.query,
      searchMode: searchMode ?? this.searchMode,
      selectedSportId: selectedSportId ?? this.selectedSportId,
      videos: videos ?? this.videos,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object> get props => [
    query,
    searchMode,
    selectedSportId ?? '',
    videos,
    totalCount,
    hasMore,
    nextOffset,
    isLoadingMore,
  ];
}

final class ExploreError extends ExploreState {
  const ExploreError({
    required this.message,
    required this.query,
    required this.searchMode,
    this.selectedSportId,
  });

  final String message;
  final String query;
  final ExploreSearchMode searchMode;
  final String? selectedSportId;

  @override
  List<Object> get props => [message, query, searchMode, selectedSportId ?? ''];
}
