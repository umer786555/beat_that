part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object> get props => [];
}

class LoadProfileEvent extends ProfileEvent {
  const LoadProfileEvent();
}

class LogoutEvent extends ProfileEvent {
  const LogoutEvent();
}

class RequestCameraPermissionEvent extends ProfileEvent {
  const RequestCameraPermissionEvent();
}

class RequestGalleryPermissionEvent extends ProfileEvent {
  const RequestGalleryPermissionEvent();
}

class RecordVideoSelected extends ProfileEvent {
  const RecordVideoSelected();
}

class UploadFromGallerySelected extends ProfileEvent {
  const UploadFromGallerySelected();
}
