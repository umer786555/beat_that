part of 'home_bloc.dart';

sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

/// Initial state
final class HomeInitial extends HomeState {}

/// No user profile found
final class NoUserProfile extends HomeState {
  const NoUserProfile();
}

/// First page of the feed is loading (initial load or refresh)
final class FeedLoading extends HomeState {
  const FeedLoading();
}

/// Feed loaded successfully
/// [videos] - List of scored, deduplicated videos for the current session
/// [offset] - Number of videos before the most recently added page
/// [hasMoreContent] - Whether more content is available (for pagination logic)
/// [nextCursor] - Per-source cursor used for the next continuation fetch
/// [isLoadingMore] - Whether the next page is being fetched
final class FeedLoaded extends HomeState {
  final List<SportVideo> videos;
  final int offset;
  final bool hasMoreContent;
  final HomeFeedCursor nextCursor;
  final bool isLoadingMore;

  const FeedLoaded({
    required this.videos,
    this.offset = 0,
    this.hasMoreContent = true,
    this.nextCursor = const HomeFeedCursor.initial(),
    this.isLoadingMore = false,
  });

  @override
  List<Object> get props => [
    videos,
    offset,
    hasMoreContent,
    nextCursor,
    isLoadingMore,
  ];
}

/// Feed loading failed
final class FeedError extends HomeState {
  final String message;
  final int? offset;

  const FeedError({required this.message, this.offset});

  @override
  List<Object> get props => [message, offset ?? 0];
}
