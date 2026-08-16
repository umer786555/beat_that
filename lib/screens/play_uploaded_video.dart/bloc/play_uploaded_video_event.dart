part of 'play_uploaded_video_bloc.dart';

sealed class PlayUploadedVideoEvent extends Equatable {
  const PlayUploadedVideoEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the video player with the video path
class InitializeVideoEvent extends PlayUploadedVideoEvent {
  const InitializeVideoEvent();
}

/// Play the video
class PlayVideoEvent extends PlayUploadedVideoEvent {
  const PlayVideoEvent();
}

/// Pause the video
class PauseVideoEvent extends PlayUploadedVideoEvent {
  const PauseVideoEvent();
}

/// Seek to a specific position in the video
class SeekVideoEvent extends PlayUploadedVideoEvent {
  final Duration position;

  const SeekVideoEvent(this.position);

  @override
  List<Object?> get props => [position];
}

/// Dispose video player resources
class DisposeVideoEvent extends PlayUploadedVideoEvent {
  const DisposeVideoEvent();
}






