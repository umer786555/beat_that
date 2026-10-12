import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:beat_that/widgets/pooled_video_surface.dart';
import 'package:beat_that/widgets/video_overlay_action_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../home_video_feed_utils.dart';

class HomeVideoFeedPage extends StatelessWidget {
  const HomeVideoFeedPage({
    super.key,
    required this.video,
    required this.slot,
    required this.isCurrentVideo,
    required this.errorMessage,
    required this.isLoadingMore,
    required this.showChrome,
    required this.onToggleChrome,
    required this.onTogglePlayback,
    required this.currentUserRating,
    this.onOpenRating,
    this.onRetry,
    this.onOpenCreatorProfile,
  });

  final SportVideo video;
  final ValueListenable<VideoSlot> slot;
  final bool isCurrentVideo;
  final String? errorMessage;
  final bool isLoadingMore;
  final bool showChrome;
  final VoidCallback onToggleChrome;
  final VoidCallback onTogglePlayback;
  final int? currentUserRating;
  final VoidCallback? onOpenRating;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenCreatorProfile;

  @override
  Widget build(BuildContext context) {
    final title = video.title;
    final username = video.username ?? 'Unknown';
    final description = video.description;
    final viewCount = video.viewCount;
    final rating = video.averageRating;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: isCurrentVideo ? onToggleChrome : null,
      child: ValueListenableBuilder<VideoSlot>(
        valueListenable: slot,
        builder: (context, slot, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              PooledVideoSurface(
                slot: slot,
                thumbnailUrl: video.thumbnailUrl,
                showLoadingIndicator: isCurrentVideo,
              ),
              _VideoFeedOverlayChrome(
                slot: slot,
                showChrome: showChrome,
                overlayMessage: videoErrorOverlayMessage(
                  slot: slot,
                  errorMessage: errorMessage,
                  isCurrentVideo: isCurrentVideo,
                ),
                isCurrentVideo: isCurrentVideo,
                username: username,
                title: title,
                description: description,
                viewCount: viewCount,
                rating: rating,
                isLoadingMore: isLoadingMore,
                canRateVideo: video.ratingTargetId != null,
                currentUserRating: currentUserRating,
                onTogglePlayback: onTogglePlayback,
                onOpenRating: onOpenRating,
                onRetry: onRetry,
                onOpenCreatorProfile: onOpenCreatorProfile,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VideoFeedOverlayChrome extends StatelessWidget {
  const _VideoFeedOverlayChrome({
    required this.slot,
    required this.showChrome,
    required this.overlayMessage,
    required this.isCurrentVideo,
    required this.username,
    required this.title,
    required this.description,
    required this.viewCount,
    required this.rating,
    required this.isLoadingMore,
    required this.canRateVideo,
    required this.currentUserRating,
    required this.onTogglePlayback,
    required this.onOpenRating,
    required this.onRetry,
    required this.onOpenCreatorProfile,
  });

  final VideoSlot slot;
  final bool showChrome;
  final String? overlayMessage;
  final bool isCurrentVideo;
  final String username;
  final String title;
  final String description;
  final int viewCount;
  final double rating;
  final bool isLoadingMore;
  final bool canRateVideo;
  final int? currentUserRating;
  final VoidCallback onTogglePlayback;
  final VoidCallback? onOpenRating;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenCreatorProfile;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showChrome) const _VideoFeedGradientOverlay(),
        _VideoFeedStateOverlay(message: overlayMessage, onRetry: onRetry),
        if (showChrome && isCurrentVideo)
          _VideoPlaybackToggleButton(slot: slot, onPressed: onTogglePlayback),
        if (showChrome)
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: canRateVideo ? 16 : 0),
                      child: _VideoMetadataSection(
                        username: username,
                        title: title,
                        description: description,
                        viewCount: viewCount,
                        rating: rating,
                        isLoadingMore: isLoadingMore,
                        onOpenCreatorProfile: onOpenCreatorProfile,
                      ),
                    ),
                  ),
                  if (canRateVideo)
                    VideoOverlayActionButton(
                      icon: Icons.star_rounded,
                      label: currentUserRating == null
                          ? 'Rate'
                          : '${currentUserRating!}/10',
                      accentColor: Colors.amber,
                      onTap: onOpenRating,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoFeedGradientOverlay extends StatelessWidget {
  const _VideoFeedGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.70),
          ],
        ),
      ),
    );
  }
}

class _VideoFeedStateOverlay extends StatelessWidget {
  const _VideoFeedStateOverlay({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message != null && onRetry != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _VideoPlaybackToggleButton extends StatelessWidget {
  const _VideoPlaybackToggleButton({
    required this.slot,
    required this.onPressed,
  });

  final VideoSlot slot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (slot.status != VideoSlotStatus.ready) {
      return const SizedBox.shrink();
    }

    return Center(
      child: InteractiveButton(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(
            slot.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}

class _VideoMetadataSection extends StatelessWidget {
  const _VideoMetadataSection({
    required this.username,
    required this.title,
    required this.description,
    required this.viewCount,
    required this.rating,
    required this.isLoadingMore,
    required this.onOpenCreatorProfile,
  });

  final String username;
  final String title;
  final String description;
  final int viewCount;
  final double rating;
  final bool isLoadingMore;
  final VoidCallback? onOpenCreatorProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onOpenCreatorProfile,
          child: Text(
            '@$username',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _VideoInfoChip(
              icon: Icons.visibility_outlined,
              label: formatViewCount(viewCount),
            ),
            const SizedBox(width: 8),
            _VideoInfoChip(
              icon: Icons.star_rounded,
              label: rating.toStringAsFixed(1),
              iconColor: Colors.amber,
            ),
          ],
        ),
        if (isLoadingMore) ...[
          const SizedBox(height: 18),
          const _LoadingMoreIndicator(),
        ],
      ],
    );
  }
}

class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
          ),
        ),
        SizedBox(width: 10),
        Text('Loading more videos', style: TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _VideoInfoChip extends StatelessWidget {
  const _VideoInfoChip({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
