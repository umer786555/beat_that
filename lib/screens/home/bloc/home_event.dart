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

/// Fetch the home feed with 40/30/20/10 blending
/// [limit] - number of videos to fetch (default: 50)
/// [offset] - pagination offset (default: 0)
final class FetchFeedEvent extends HomeEvent {
  final int limit;
  final int offset;

  const FetchFeedEvent({
    this.limit = 50,
    this.offset = 0,
  });

  @override
  List<Object> get props => [limit, offset];
}

/// Refresh the feed from the top (offset=0)
final class RefreshFeedEvent extends HomeEvent {
  const RefreshFeedEvent();
}

/// Load next page of feed (pagination)
final class LoadMoreFeedEvent extends HomeEvent {
  const LoadMoreFeedEvent();
}
