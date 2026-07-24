import 'package:beat_that/models/video_thumbnail_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/widgets/thumbnail_error_widget.dart';

/// Reusable widget for displaying a video thumbnail item in grid view
/// Displays video thumbnail with YouTube-style loading shimmer and theme support
/// Supports long-press for Instagram-style deletion
class VideoThumbnailItem extends StatelessWidget {
  final VideoThumbnailModel thumbnail;
  final bool isDark;
  final VoidCallback onTap;
  final Function(VideoThumbnailModel)? onLongPress;

  const VideoThumbnailItem({
    super.key,
    required this.thumbnail,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  /// YouTube-style shimmer colors for loading state
  Color _getShimmerBaseColor() {
    return isDark ? const Color(0xFF313131) : const Color(0xFFF0F0F0);
  }

  Color _getShimmerHighlightColor() {
    return isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0);
  }

  /// Format view count in human-readable format (1.2M, 500K, etc.) - YouTube style
  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else if (count == 0) {
      return '0';
    } else {
      return '$count';
    }
  }

  /// Format rating for display
  String _formatRating(double rating) {
    if (rating == 0) {
      return 'No ratings';
    }
    return rating.toStringAsFixed(1);
  }

  String? _buildSportLabel() {
    final sportId = thumbnail.sportId;
    if (sportId == null || sportId.isEmpty) {
      return null;
    }

    return getDisplayNameForSport(sportId);
  }

  String? _buildSubcategoryLabel() {
    final subcategoryName = thumbnail.subcategoryName;
    if (subcategoryName == null || subcategoryName.isEmpty) {
      return null;
    }

    return subcategoryName;
  }

  @override
  Widget build(BuildContext context) {
    final sportLabel = _buildSportLabel();
    final subcategoryLabel = _buildSubcategoryLabel();

    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        HapticFeedback.heavyImpact();
        if (onLongPress != null) {
          onLongPress!(thumbnail);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail with play button and info overlay
          Expanded(
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Main thumbnail image
                    Image.network(
                      thumbnail.thumbnailUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        // YouTube-style shimmer effect
                        return Shimmer.fromColors(
                          baseColor: _getShimmerBaseColor(),
                          highlightColor: _getShimmerHighlightColor(),
                          period: const Duration(milliseconds: 1200),
                          child: Container(color: _getShimmerBaseColor()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return ThumbnailErrorWidget(
                          isDark: isDark,
                          onRetry: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to load thumbnail. Tap to retry.',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Play button - centered
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.85),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: isDark
                              ? AppColors.electricPurple
                              : AppColors.electricMagenta,
                        ),
                      ),
                    ),
                    // Bottom info overlay with gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            Text(
                              thumbnail.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (sportLabel != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                sportLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                            if (subcategoryLabel != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subcategoryLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.74),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            // Stats row with rating and views
                            Row(
                              children: [
                                // Rating badge
                                if (thumbnail.averageRating > 0)
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 13,
                                          color: Colors.amber[300],
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatRating(thumbnail.averageRating),
                                          style: TextStyle(
                                            color: Colors.amber[100],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: Text(
                                      'No ratings',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                // Divider
                                Container(
                                  width: 1,
                                  height: 12,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(width: 12),
                                // View count
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility_rounded,
                                        size: 13,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        thumbnail.viewCount > 0
                                            ? '${_formatViewCount(thumbnail.viewCount)} views'
                                            : 'No views',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
