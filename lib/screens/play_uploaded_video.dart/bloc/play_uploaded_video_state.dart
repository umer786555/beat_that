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

/// Video initialized: ready, playing, or paused.
sealed class PlayUploadedVideoLoaded extends PlayUploadedVideoState {
  final Duration duration;
  final Duration currentPosition;

  const PlayUploadedVideoLoaded({
    required this.duration,
    required this.currentPosition,
  });

  @override
  List<Object?> get props => [duration, currentPosition];
}

/// Video ready and can be played
final class PlayUploadedVideoReady extends PlayUploadedVideoLoaded {
  final bool isPlaying;

  const PlayUploadedVideoReady({
    required super.duration,
    required super.currentPosition,
    required this.isPlaying,
  });

  @override
  List<Object?> get props => [...super.props, isPlaying];
}

/// Video is playing
final class PlayUploadedVideoPlaying extends PlayUploadedVideoLoaded {
  const PlayUploadedVideoPlaying({
    required super.duration,
    required super.currentPosition,
  });
}

/// Video is paused
final class PlayUploadedVideoPaused extends PlayUploadedVideoLoaded {
  const PlayUploadedVideoPaused({
    required super.duration,
    required super.currentPosition,
  });
}

/// Error state
final class PlayUploadedVideoError extends PlayUploadedVideoState {
  final String message;

  const PlayUploadedVideoError(this.message);

  @override
  List<Object?> get props => [message];
}
