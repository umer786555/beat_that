import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/thumbnail_error_widget.dart';

/// Reusable widget for displaying a video thumbnail item in grid view
/// Displays video thumbnail with YouTube-style loading shimmer and theme support
class VideoThumbnailItem extends StatelessWidget {
  final Map<String, dynamic> thumbnail;
  final bool isDark;
  final VoidCallback onTap;

  const VideoThumbnailItem({
    super.key,
    required this.thumbnail,
    required this.isDark,
    required this.onTap,
  });

  /// YouTube-style shimmer colors for loading state
  Color _getShimmerBaseColor() {
    return isDark ? const Color(0xFF313131) : const Color(0xFFF0F0F0);
  }

  Color _getShimmerHighlightColor() {
    return isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail with play button - using Material elevation for depth
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
                      thumbnail['thumbnail_url'] as String,
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
                    // Dark gradient overlay for better play button visibility
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.45),
                          ],
                        ),
                      ),
                    ),
                    // Play button with improved styling
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.7),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(11),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 30,
                          color: isDark
                              ? AppColors.electricPurple
                              : AppColors.electricMagenta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Title section with improved typography and spacing
          const SizedBox(height: 10),
          Text(
            thumbnail['title'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
