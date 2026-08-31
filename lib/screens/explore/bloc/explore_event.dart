part of 'explore_bloc.dart';

sealed class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object> get props => [];
}

final class SearchExploreVideosEvent extends ExploreEvent {
  const SearchExploreVideosEvent({
    required this.query,
    this.selectedSportId,
  });

  final String query;
  final String? selectedSportId;

  @override
  List<Object> get props => [query, selectedSportId ?? ''];
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
