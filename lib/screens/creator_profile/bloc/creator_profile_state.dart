part of 'creator_profile_bloc.dart';

sealed class CreatorProfileState extends Equatable {
  const CreatorProfileState();

  @override
  List<Object> get props => [];
}

final class CreatorProfileInitial extends CreatorProfileState {
  const CreatorProfileInitial();
}

final class CreatorProfileLoading extends CreatorProfileState {
  const CreatorProfileLoading();
}

final class CreatorProfileLoaded extends CreatorProfileState {
  const CreatorProfileLoaded({
    required this.profile,
    required this.videos,
    required this.totalVideoCount,
    required this.isFollowing,
    required this.isOwnProfile,
    required this.hasMoreVideos,
    this.isUpdatingFollow = false,
    this.isLoadingMore = false,
  });

  final UserPersonalProfile profile;
  final List<VideoThumbnailModel> videos;
  final int totalVideoCount;
  final bool isFollowing;
  final bool isOwnProfile;
  final bool hasMoreVideos;
  final bool isUpdatingFollow;
  final bool isLoadingMore;

  CreatorProfileLoaded copyWith({
    UserPersonalProfile? profile,
    List<VideoThumbnailModel>? videos,
    int? totalVideoCount,
    bool? isFollowing,
    bool? isOwnProfile,
    bool? hasMoreVideos,
    bool? isUpdatingFollow,
    bool? isLoadingMore,
  }) {
    return CreatorProfileLoaded(
      profile: profile ?? this.profile,
      videos: videos ?? this.videos,
      totalVideoCount: totalVideoCount ?? this.totalVideoCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      hasMoreVideos: hasMoreVideos ?? this.hasMoreVideos,
      isUpdatingFollow: isUpdatingFollow ?? this.isUpdatingFollow,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object> get props => [
    profile.username,
    profile.profileUrl ?? '',
    videos,
    totalVideoCount,
    isFollowing,
    isOwnProfile,
    hasMoreVideos,
    isUpdatingFollow,
    isLoadingMore,
  ];
}

final class CreatorProfileError extends CreatorProfileState {
  const CreatorProfileError({required this.message});

  final String message;

  @override
  List<Object> get props => [message];
}
