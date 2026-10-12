import 'package:equatable/equatable.dart';

/// Where playback is, independent of the player package that produced it.
class PlaybackProgress extends Equatable {
  const PlaybackProgress({
    required this.position,
    required this.duration,
    required this.isPlaying,
  });

  static const zero = PlaybackProgress(
    position: Duration.zero,
    duration: Duration.zero,
    isPlaying: false,
  );

  final Duration position;
  final Duration duration;
  final bool isPlaying;

  PlaybackProgress copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
  }) {
    return PlaybackProgress(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  @override
  List<Object?> get props => [position, duration, isPlaying];
}
