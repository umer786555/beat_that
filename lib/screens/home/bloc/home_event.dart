part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

/// Triggered on app initialization
/// Saves user profile and fetches initial feed
final class InitialEvent extends HomeEvent {
  const InitialEvent();
}

/// Refresh the feed from the top (offset=0)
final class RefreshFeedEvent extends HomeEvent {
  const RefreshFeedEvent();
}

/// Load next page of feed (pagination)
final class LoadMoreFeedEvent extends HomeEvent {
  const LoadMoreFeedEvent();
}

/// Adds pages loaded in the full-screen feed back into the Home grid.
final class MergeVideoFeedSessionEvent extends HomeEvent {
  const MergeVideoFeedSessionEvent({
    required this.videos,
    required this.nextCursor,
    required this.hasMoreContent,
  });

  final List<SportVideo> videos;
  final HomeFeedCursor nextCursor;
  final bool hasMoreContent;

  @override
  List<Object> get props => [videos, nextCursor, hasMoreContent];
}
