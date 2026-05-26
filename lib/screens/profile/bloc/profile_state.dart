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
  final List<Map<String, dynamic>> thumbnails;
  final String? username;
  final String? profileUrl;

  const ProfileLoaded({
    required this.cameraPermissionEnabled,
    required this.galleryPermissionEnabled,
    this.thumbnails = const [],
    this.username,
    this.profileUrl,
  });

  @override
  List<Object> get props => [cameraPermissionEnabled, galleryPermissionEnabled, thumbnails, username ?? '', profileUrl ?? ''];

  ProfileLoaded copyWith({
    AppThemeMode? currentTheme,
    bool? cameraPermissionEnabled,
    bool? galleryPermissionEnabled,
    List<Map<String, dynamic>>? thumbnails,
    String? username,
    String? profileUrl,
  }) {
    return ProfileLoaded(
      cameraPermissionEnabled: cameraPermissionEnabled ?? this.cameraPermissionEnabled,
      galleryPermissionEnabled: galleryPermissionEnabled ?? this.galleryPermissionEnabled,
      thumbnails: thumbnails ?? this.thumbnails,
      username: username ?? this.username,
      profileUrl: profileUrl ?? this.profileUrl,
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


