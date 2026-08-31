part of 'home_bloc.dart';

sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

/// Initial state
final class HomeInitial extends HomeState {}

/// User profile has been loaded and saved
final class UserProfileLoaded extends HomeState {
  final UserPersonalProfile userProfile;

  const UserProfileLoaded(this.userProfile);

  @override
  List<Object> get props => [userProfile];
}

/// No user profile found
final class NoUserProfile extends HomeState {
  const NoUserProfile();
}

/// Feed is currently loading
final class FeedLoading extends HomeState {
  final int offset;
  final bool isFirstLoad;

  const FeedLoading({required this.offset, this.isFirstLoad = true});

  @override
  List<Object> get props => [offset, isFirstLoad];
}

/// Feed loaded successfully
/// [videos] - List of blended videos (40/30/20/10 distribution)
/// [offset] - Current pagination offset
/// [hasMoreContent] - Whether more content is available (for pagination logic)
/// [nextCursor] - Per-source cursor used for the next continuation fetch
final class FeedLoaded extends HomeState {
  final List<SportVideo> videos;
  final int offset;
  final bool hasMoreContent;
  final HomeFeedCursor nextCursor;

  const FeedLoaded({
    required this.videos,
    this.offset = 0,
    this.hasMoreContent = true,
    this.nextCursor = const HomeFeedCursor.initial(),
  });

  @override
  List<Object> get props => [videos, offset, hasMoreContent, nextCursor];
}

/// Feed loading failed
final class FeedError extends HomeState {
  final String message;
  final int? offset;

  const FeedError({
    required this.message,
    this.offset,
  });

  @override
  List<Object> get props => [message, offset ?? 0];
}
