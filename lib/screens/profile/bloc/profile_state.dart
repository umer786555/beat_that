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
  final List<VideoThumbnailModel> thumbnails;
  final String? username;
  final String? profileUrl;
  final int followers;
  final int following;

  const ProfileLoaded({
    required this.cameraPermissionEnabled,
    required this.galleryPermissionEnabled,
    this.thumbnails = const [],
    this.username,
    this.profileUrl,
    this.followers = 0,
    this.following = 0,
  });

  @override
  List<Object> get props => [cameraPermissionEnabled, galleryPermissionEnabled, thumbnails, username ?? '', profileUrl ?? '', followers, following];

  ProfileLoaded copyWith({
    AppThemeMode? currentTheme,
    bool? cameraPermissionEnabled,
    bool? galleryPermissionEnabled,
    List<VideoThumbnailModel>? thumbnails,
    String? username,
    String? profileUrl,
    int? followers,
    int? following,
  }) {
    return ProfileLoaded(
      cameraPermissionEnabled: cameraPermissionEnabled ?? this.cameraPermissionEnabled,
      galleryPermissionEnabled: galleryPermissionEnabled ?? this.galleryPermissionEnabled,
      thumbnails: thumbnails ?? this.thumbnails,
      username: username ?? this.username,
      profileUrl: profileUrl ?? this.profileUrl,
      followers: followers ?? this.followers,
      following: following ?? this.following,
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

  const CameraPermissionDenied({
    this.isPermanentlyDenied = false,
  });

  @override
  List<Object> get props => [ isPermanentlyDenied];
}


// Video upload states
final class RecordVideoMode extends ProfileState {
  const RecordVideoMode();
}

final class UploadFromGalleryMode extends ProfileState {
  const UploadFromGalleryMode();
}


