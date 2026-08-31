import 'package:beat_that/constants/app_colors.dart';
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
  static String formatViewCount(int count) {
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
    final formattedViews = VideoFeedCard.formatViewCount(viewCount);
    final sportLabel = sportId != null && sportId!.isNotEmpty
        ? getDisplayNameForSport(sportId!)
        : null;
    final sportIcon = sportId != null && sportId!.isNotEmpty
        ? getIconForSport(sportId!)
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail image
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
              // Modern gradient overlay - inspired by Instagram/TikTok
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Top sport badge
              if (sportLabel != null && sportIcon != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _ModernSportBadge(icon: sportIcon, label: sportLabel),
                ),
              // Bottom content area
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomContentOverlay(
                  username: username,
                  formattedViews: formattedViews,
                  rating: rating,
                  onUsernameTap: onUsernameTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle sport badge with minimalist design
class _ModernSportBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ModernSportBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 5),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Modern bottom overlay showing creator info and engagement metrics
class _BottomContentOverlay extends StatelessWidget {
  final String? username;
  final String formattedViews;
  final double rating;
  final VoidCallback? onUsernameTap;

  const _BottomContentOverlay({
    required this.username,
    required this.formattedViews,
    required this.rating,
    this.onUsernameTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator name (if available)
          if (username != null && username!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: onUsernameTap,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.electricMagenta,
                            AppColors.electricPurple,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        username!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Engagement metrics
          Row(
            children: [
              // View count with icon
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      formattedViews,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Rating with animated star
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.yellowDark,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
