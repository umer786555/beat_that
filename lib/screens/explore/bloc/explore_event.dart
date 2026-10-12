part of 'explore_bloc.dart';

sealed class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object> get props => [];
}

final class LoadExploreFiltersEvent extends ExploreEvent {
  const LoadExploreFiltersEvent();
}

final class SearchExploreVideosEvent extends ExploreEvent {
  const SearchExploreVideosEvent({
    required this.query,
    this.selectedFilterId,
  });

  final String query;
  final String? selectedFilterId;

  @override
  List<Object> get props => [query, selectedFilterId ?? ''];
}

final class LoadMoreExploreVideosEvent extends ExploreEvent {
  const LoadMoreExploreVideosEvent({this.isRetry = false});

  /// True when the user explicitly asks to retry a failed page.
  final bool isRetry;

  @override
  List<Object> get props => [isRetry];
}

final class RefreshExploreVideosEvent extends ExploreEvent {
  const RefreshExploreVideosEvent();
}

final class RetryExploreSearchEvent extends ExploreEvent {
  const RetryExploreSearchEvent();
}

/// Adds pages loaded in the full-screen feed back into the grid.
final class MergeExploreFeedProgressEvent extends ExploreEvent {
  const MergeExploreFeedProgressEvent(this.progress);

  final ExploreFeedProgress progress;

  @override
  List<Object> get props => [progress];
}
