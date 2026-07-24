part of 'explore_bloc.dart';

sealed class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object> get props => [];
}

final class SearchExploreVideosEvent extends ExploreEvent {
  const SearchExploreVideosEvent({
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

final class LoadMoreExploreVideosEvent extends ExploreEvent {
  const LoadMoreExploreVideosEvent();
}

final class RefreshExploreVideosEvent extends ExploreEvent {
  const RefreshExploreVideosEvent();
}

final class RetryExploreSearchEvent extends ExploreEvent {
  const RetryExploreSearchEvent();
}
