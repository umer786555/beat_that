import 'package:equatable/equatable.dart';
import 'package:media_kit_video/media_kit_video.dart';

enum VideoSlotStatus { loading, ready, error }

/// What a feed page needs to render one video from the pool.
///
/// Immutable so a `ValueNotifier<VideoSlot>` only notifies on real changes.
class VideoSlot extends Equatable {
  const VideoSlot({
    required this.status,
    this.videoController,
    this.isPlaying = false,
  });

  /// An unassigned or evicted key: no controller, so the thumbnail shows.
  const VideoSlot.loading() : this(status: VideoSlotStatus.loading);

  final VideoSlotStatus status;
  final VideoController? videoController;
  final bool isPlaying;

  VideoSlot copyWith({
    VideoSlotStatus? status,
    VideoController? videoController,
    bool? isPlaying,
  }) {
    return VideoSlot(
      status: status ?? this.status,
      videoController: videoController ?? this.videoController,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  @override
  List<Object?> get props => [status, videoController, isPlaying];
}
