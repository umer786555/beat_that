import 'package:beat_that/constants/sports_data.dart';
import 'package:flutter/material.dart';

/// Reusable video feed card component for displaying videos in grid
class VideoFeedCard extends StatelessWidget {
  final String videoId;
  final String thumbnailUrl;
  final String? username;
  final String? sportId;
  final int viewCount;
  final double rating;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const VideoFeedCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    this.username,
    this.sportId,
    required this.viewCount,
    required this.rating,
    required this.onTap,
    this.onLongPress,
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
    final sportLabel = sportId != null && sportId!.isNotEmpty
        ? getDisplayNameForSport(sportId!)
        : null;
    final sportIcon = sportId != null && sportId!.isNotEmpty
        ? getIconForSport(sportId!)
        : null;

    // Debug: log the thumbnail URL
    print(
      '🖼️ VideoFeedCard build - videoId: $videoId, thumbnailUrl: $thumbnailUrl',
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          /// Main video thumbnail container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.grey[300],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  /// Thumbnail image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print(
                          '❌ VideoFeedCard Image.network ERROR - videoId: $videoId',
                        );
                        print('   URL attempted: $thumbnailUrl');
                        print('   Error: $error');
                        print('   StackTrace: $stackTrace');
                        return Container(
                          color: Colors.grey[400],
                          child: const Center(
                            child: Icon(
                              Icons.video_library_outlined,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(child: SizedBox.shrink()),
                        );
                      },
                    ),
                  ),

                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.06),
                          Colors.black.withOpacity(0.18),
                          Colors.black.withOpacity(0.78),
                        ],
                        stops: const [0.0, 0.38, 1.0],
                      ),
                    ),
                  ),

                  /// Play button overlay
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.28),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  if (sportLabel != null && sportIcon != null)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.48),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.26),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(sportIcon, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  sportLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  /// Bottom left info (username + view count + rating)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Username with avatar
                        if (username != null)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '@$username',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),

                        /// View count + Rating + Source
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatChip(
                              icon: Icons.visibility_outlined,
                              label: formattedViews,
                            ),
                            _StatChip(
                              icon: Icons.star_rounded,
                              label: rating.toStringAsFixed(1),
                              iconColor: Colors.amber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _StatChip({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
