part of 'play_uploaded_video_bloc.dart';

sealed class PlayUploadedVideoState extends Equatable {
  const PlayUploadedVideoState();

  @override
  List<Object?> get props => [];
}

/// Initial state
final class PlayUploadedVideoInitial extends PlayUploadedVideoState {}

/// Loading state - video is initializing
final class PlayUploadedVideoLoading extends PlayUploadedVideoState {}

/// Video ready and can be played
final class PlayUploadedVideoReady extends PlayUploadedVideoState {
  final Duration duration;
  final Duration currentPosition;
  final bool isPlaying;

  const PlayUploadedVideoReady({
    required this.duration,
    required this.currentPosition,
    required this.isPlaying,
  });

  @override
  List<Object?> get props => [duration, currentPosition, isPlaying];
}

/// Video is playing
final class PlayUploadedVideoPlaying extends PlayUploadedVideoState {
  final Duration duration;
  final Duration currentPosition;

  const PlayUploadedVideoPlaying({
    required this.duration,
    required this.currentPosition,
  });

  @override
  List<Object?> get props => [duration, currentPosition];
}

/// Video is paused
final class PlayUploadedVideoPaused extends PlayUploadedVideoState {
  final Duration duration;
  final Duration currentPosition;

  const PlayUploadedVideoPaused({
    required this.duration,
    required this.currentPosition,
  });

  @override
  List<Object?> get props => [duration, currentPosition];
}

/// Error state
final class PlayUploadedVideoError extends PlayUploadedVideoState {
  final String message;

  const PlayUploadedVideoError(this.message);

  @override
  List<Object?> get props => [message];
}
