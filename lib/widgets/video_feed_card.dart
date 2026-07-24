import 'package:beat_that/constants/sports_data.dart';
import 'package:flutter/material.dart';

/// Reusable video feed card component for displaying videos in grid
class VideoFeedCard extends StatelessWidget {
  final String videoId;
  final String thumbnailUrl;
  final String? title;
  final String? username;
  final String? sportId;
  final int viewCount;
  final double rating;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onUsernameTap;

  const VideoFeedCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    this.title,
    this.username,
    this.sportId,
    required this.viewCount,
    required this.rating,
    required this.onTap,
    this.onLongPress,
    this.onUsernameTap,
  });

  /// Format view count as 1.2M, 500K, etc.
  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedViews = _formatViewCount(viewCount);
    final theme = Theme.of(context);
    final trimmedTitle = title?.trim();
    final hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
    final trimmedUsername = username?.trim();
    final hasUsername = trimmedUsername != null && trimmedUsername.isNotEmpty;
    final sportLabel = sportId != null && sportId!.isNotEmpty
        ? getDisplayNameForSport(sportId!)
        : null;
    final sportIcon = sportId != null && sportId!.isNotEmpty
        ? getIconForSport(sportId!)
        : null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF323846),
                  child: const Center(
                    child: Icon(
                      Icons.video_library_outlined,
                      color: Colors.white70,
                      size: 36,
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: const Color(0xFFCDD3DD));
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.02),
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.78),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.topLeft,
                child: sportLabel != null && sportIcon != null
                    ? _OverlayChip(
                        icon: sportIcon,
                        label: sportLabel,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUsername)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onUsernameTap,
                      child: Text(
                        '@$trimmedUsername',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (hasUsername && hasTitle) const SizedBox(height: 4),
                  if (hasTitle)
                    Text(
                      trimmedTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (hasTitle || hasUsername) const SizedBox(height: 8),
                  Row(
                    children: [
                      _InlineStat(
                        icon: Icons.visibility_outlined,
                        label: formattedViews,
                      ),
                      const Spacer(),
                      _InlineStat(
                        icon: Icons.star_rounded,
                        label: rating.toStringAsFixed(1),
                        iconColor: const Color(0xFFFFC94D),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverlayChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _InlineStat({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white.withOpacity(0.92),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
