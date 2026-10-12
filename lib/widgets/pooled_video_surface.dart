import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Renders one feed video from a pool [slot].
///
/// The thumbnail covers the surface until the slot is ready, so a reused
/// player never flashes the previous source's last frame.
class PooledVideoSurface extends StatelessWidget {
  const PooledVideoSurface({
    super.key,
    required this.slot,
    required this.thumbnailUrl,
    required this.showLoadingIndicator,
  });

  final VideoSlot slot;
  final String? thumbnailUrl;

  /// Only the current page shows a spinner, and only while its slot loads.
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) {
    final videoController = slot.videoController;
    final thumbnailUrl = this.thumbnailUrl;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoController != null)
            Video(
              controller: videoController,
              fit: BoxFit.cover,
              controls: NoVideoControls,
              // The pool pauses on background through its lifecycle listener.
              pauseUponEnteringBackgroundMode: false,
            ),
          if (slot.status != VideoSlotStatus.ready)
            thumbnailUrl == null
                ? const _VideoPlaceholder()
                : Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _VideoPlaceholder(),
                  ),
          if (showLoadingIndicator && slot.status == VideoSlotStatus.loading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// The message for a page's error/retry overlay, or null to hide it.
///
/// The overlay only appears on the current page while no video is showing.
String? videoErrorOverlayMessage({
  required VideoSlot slot,
  required String? errorMessage,
  required bool isCurrentVideo,
}) {
  if (!isCurrentVideo || slot.status == VideoSlotStatus.ready) {
    return null;
  }

  if (slot.status == VideoSlotStatus.error) {
    return 'Failed to load video. Tap to retry.';
  }

  return errorMessage;
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}
