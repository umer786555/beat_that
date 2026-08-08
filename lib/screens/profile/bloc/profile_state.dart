part of 'profile_bloc.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object> get props => [];
}

final class ProfileInitial extends ProfileState {}

final class ProfileLoaded extends ProfileState {
  final bool cameraPermissionEnabled;
  final bool galleryPermissionEnabled;
  final List<MyVideo> myVideo;
  final String? username;
  final String? profileUrl;
  final bool isDeletingVideo;

  const ProfileLoaded({
    required this.cameraPermissionEnabled,
    required this.galleryPermissionEnabled,
    this.myVideo = const [],
    this.username,
    this.profileUrl,
    this.isDeletingVideo = false,
  });

  @override
  List<Object> get props => [
    cameraPermissionEnabled,
    galleryPermissionEnabled,
    myVideo,
    username ?? '',
    profileUrl ?? '',
    isDeletingVideo,
  ];

  ProfileLoaded copyWith({
    AppThemeMode? currentTheme,
    bool? cameraPermissionEnabled,
    bool? galleryPermissionEnabled,
    List<MyVideo>? thumbnails,
    String? username,
    String? profileUrl,
    bool? isDeletingVideo,
  }) {
    return ProfileLoaded(
      cameraPermissionEnabled:
          cameraPermissionEnabled ?? this.cameraPermissionEnabled,
      galleryPermissionEnabled:
          galleryPermissionEnabled ?? this.galleryPermissionEnabled,
      myVideo: thumbnails ?? this.myVideo,
      username: username ?? this.username,
      profileUrl: profileUrl ?? this.profileUrl,
      isDeletingVideo: isDeletingVideo ?? this.isDeletingVideo,
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
