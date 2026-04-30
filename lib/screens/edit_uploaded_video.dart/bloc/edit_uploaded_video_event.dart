part of 'edit_uploaded_video_bloc.dart';

sealed class EditUploadedVideoEvent extends Equatable {
  const EditUploadedVideoEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the video player with the video path
class InitializeVideoEvent extends EditUploadedVideoEvent {
  final String videoPath;

  const InitializeVideoEvent(this.videoPath);

  @override
  List<Object?> get props => [videoPath];
}

/// Play the video
class PlayVideoEvent extends EditUploadedVideoEvent {
  const PlayVideoEvent();
}

/// Pause the video
class PauseVideoEvent extends EditUploadedVideoEvent {
  const PauseVideoEvent();
}

/// Seek to a specific position in the video
class SeekVideoEvent extends EditUploadedVideoEvent {
  final Duration position;

  const SeekVideoEvent(this.position);

  @override
  List<Object?> get props => [position];
}

/// Dispose video player resources
class DisposeVideoEvent extends EditUploadedVideoEvent {
  const DisposeVideoEvent();
}






