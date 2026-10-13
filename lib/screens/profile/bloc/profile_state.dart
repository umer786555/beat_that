part of 'profile_bloc.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

const Object _deletingVideoIdUnset = Object();

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileLoaded extends ProfileState {
  final List<MyVideo> myVideos;
  final String? username;
  final String? profileUrl;
  final String? deletingVideoId;

  /// True while a pull-to-refresh reload is in flight.
  final bool isRefreshing;

  /// True while a new profile photo is being uploaded.
  final bool isUploadingProfileImage;

  bool get isDeletingVideo => deletingVideoId != null;

  const ProfileLoaded({
    this.myVideos = const [],
    this.username,
    this.profileUrl,
    this.deletingVideoId,
    this.isRefreshing = false,
    this.isUploadingProfileImage = false,
  });

  @override
  List<Object?> get props => [
    myVideos,
    username,
    profileUrl,
    deletingVideoId,
    isRefreshing,
    isUploadingProfileImage,
  ];

  ProfileLoaded copyWith({
    List<MyVideo>? myVideos,
    String? username,
    String? profileUrl,
    Object? nextDeletingVideoId = _deletingVideoIdUnset,
    bool? isRefreshing,
    bool? isUploadingProfileImage,
  }) {
    return ProfileLoaded(
      myVideos: myVideos ?? this.myVideos,
      username: username ?? this.username,
      profileUrl: profileUrl ?? this.profileUrl,
      deletingVideoId: identical(nextDeletingVideoId, _deletingVideoIdUnset)
          ? deletingVideoId
          : nextDeletingVideoId as String?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isUploadingProfileImage:
          isUploadingProfileImage ?? this.isUploadingProfileImage,
    );
  }
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileError extends ProfileState {
  final String message;

  const ProfileError({required this.message});

  @override
  List<Object?> get props => [message];
}
