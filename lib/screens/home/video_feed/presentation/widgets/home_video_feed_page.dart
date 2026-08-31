import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../home_video_feed_utils.dart';

class HomeVideoFeedPage extends StatelessWidget {
  const HomeVideoFeedPage({
    super.key,
    required this.video,
    required this.controller,
    required this.isCurrentVideo,
    required this.errorMessage,
    required this.isLoadingMore,
    required this.onTogglePlayback,
    required this.currentUserRating,
    this.onOpenRating,
    this.onRetry,
    this.onOpenCreatorProfile,
  });

  final SportVideo video;
  final VideoPlayerController? controller;
  final bool isCurrentVideo;
  final String? errorMessage;
  final bool isLoadingMore;
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
    final canRateVideo = video.ratingTargetId != null;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: isCurrentVideo ? onTogglePlayback : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _VideoPlayerSurface(controller: controller),
          const _VideoFeedGradientOverlay(),
          _VideoFeedStateOverlay(
            controller: controller,
            errorMessage: errorMessage,
            isCurrentVideo: isCurrentVideo,
            onRetry: onRetry,
          ),
          Positioned(
            left: 16,
            right: 88,
            bottom: 40,
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
          if (canRateVideo)
            Positioned(
              right: 16,
              bottom: 48,
              child: SafeArea(
                top: false,
                child: _VideoActionButton(
                  icon: Icons.star_rounded,
                  label: currentUserRating == null
                      ? 'Rate'
                      : '${currentUserRating!}/10',
                  accentColor: Colors.amber,
                  onTap: onOpenRating,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPlayerSurface extends StatelessWidget {
  const _VideoPlayerSurface({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const _VideoPlaceholder();
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller!,
      builder: (context, value, child) {
        if (value.isInitialized) {
          return ColoredBox(
            color: Colors.black,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: value.size.width,
                  height: value.size.height,
                  child: VideoPlayer(controller!),
                ),
              ),
            ),
          );
        }

        return const _VideoPlaceholder();
      },
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
  const _VideoFeedStateOverlay({
    required this.controller,
    required this.errorMessage,
    required this.isCurrentVideo,
    required this.onRetry,
  });

  final VideoPlayerController? controller;
  final String? errorMessage;
  final bool isCurrentVideo;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (controller == null && errorMessage != null && onRetry != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
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

    if (controller == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller!,
        builder: (context, value, child) {
          if (!value.isInitialized || value.isPlaying || !isCurrentVideo) {
            return const SizedBox.shrink();
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
          );
        },
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
        Text(
          'Loading more videos',
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}

class _VideoActionButton extends StatelessWidget {
  const _VideoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InteractiveButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Container(color: Colors.black.withValues(alpha: 0.25)),
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
