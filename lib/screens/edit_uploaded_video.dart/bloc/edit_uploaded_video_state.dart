part of 'edit_uploaded_video_bloc.dart';

sealed class EditUploadedVideoState extends Equatable {
  const EditUploadedVideoState();

  @override
  List<Object?> get props => [];
}

/// Initial state
final class EditUploadedVideoInitial extends EditUploadedVideoState {}

/// Loading state - video is initializing
final class EditUploadedVideoLoading extends EditUploadedVideoState {}

/// Video ready and can be played
final class EditUploadedVideoReady extends EditUploadedVideoState {
  final Duration duration;
  final Duration currentPosition;
  final bool isPlaying;

  const EditUploadedVideoReady({
    required this.duration,
    required this.currentPosition,
    required this.isPlaying,
  });

  @override
  List<Object?> get props => [duration, currentPosition, isPlaying];
}

/// Video is playing
final class EditUploadedVideoPlaying extends EditUploadedVideoState {
  final Duration duration;
  final Duration currentPosition;

  const EditUploadedVideoPlaying({
    required this.duration,
    required this.currentPosition,
  });

  @override
  List<Object?> get props => [duration, currentPosition];
}

/// Video is paused
final class EditUploadedVideoPaused extends EditUploadedVideoState {
  final Duration duration;
  final Duration currentPosition;

  const EditUploadedVideoPaused({
    required this.duration,
    required this.currentPosition,
  });

  @override
  List<Object?> get props => [duration, currentPosition];
}

/// Error state
final class EditUploadedVideoError extends EditUploadedVideoState {
  final String message;

  const EditUploadedVideoError(this.message);

  @override
  List<Object?> get props => [message];
}
