part of 'profile_bloc.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object> get props => [];
}

const Object _deletingVideoIdUnset = Object();

final class ProfileInitial extends ProfileState {}

final class ProfileLoaded extends ProfileState {
  final bool cameraPermissionEnabled;
  final bool galleryPermissionEnabled;
  final List<MyVideo> myVideo;
  final String? username;
  final String? profileUrl;
  final String? deletingVideoId;

  bool get isDeletingVideo => deletingVideoId != null;

  const ProfileLoaded({
    required this.cameraPermissionEnabled,
    required this.galleryPermissionEnabled,
    this.myVideo = const [],
    this.username,
    this.profileUrl,
    this.deletingVideoId,
  });

  @override
  List<Object> get props => [
    cameraPermissionEnabled,
    galleryPermissionEnabled,
    myVideo,
    username ?? '',
    profileUrl ?? '',
    deletingVideoId ?? '',
  ];

  ProfileLoaded copyWith({
    AppThemeMode? currentTheme,
    bool? cameraPermissionEnabled,
    bool? galleryPermissionEnabled,
    List<MyVideo>? thumbnails,
    String? username,
    String? profileUrl,
    Object? nextDeletingVideoId = _deletingVideoIdUnset,
  }) {
    return ProfileLoaded(
      cameraPermissionEnabled:
          cameraPermissionEnabled ?? this.cameraPermissionEnabled,
      galleryPermissionEnabled:
          galleryPermissionEnabled ?? this.galleryPermissionEnabled,
      myVideo: thumbnails ?? myVideo,
      username: username ?? this.username,
      profileUrl: profileUrl ?? this.profileUrl,
      deletingVideoId: identical(nextDeletingVideoId, _deletingVideoIdUnset)
          ? deletingVideoId
          : nextDeletingVideoId as String?,
    );
  }
}

final class ProfileLoading extends ProfileState {}

final class ProfileError extends ProfileState {
  final String message;

  const ProfileError({required this.message});

  @override
  List<Object> get props => [message];
}

final class CameraPermissionDenied extends ProfileState {
  final bool isPermanentlyDenied;

  const CameraPermissionDenied({this.isPermanentlyDenied = false});

  @override
  List<Object> get props => [isPermanentlyDenied];
}

// Video upload states
final class RecordVideoMode extends ProfileState {
  const RecordVideoMode();
}

final class UploadFromGalleryMode extends ProfileState {
  const UploadFromGalleryMode();
}
