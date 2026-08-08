import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// A reusable empty state widget displayed when there are no videos.
///
/// Features:
/// - Large prominent icon
/// - Customizable title and subtitle
/// - Theme-aware styling (dark/light mode)
/// - Centered layout with proper spacing
/// - Returns a Sliver widget for use in CustomScrollView
///
/// Usage:
/// ```dart
/// EmptyVideosState(
///   isDark: isDark,
///   title: 'No videos yet',
///   subtitle: 'Start uploading videos to see them here',
/// )
/// ```
class EmptyVideosState extends StatelessWidget {
  /// Whether dark mode is enabled
  final bool isDark;

  /// Title text displayed (e.g., "No videos yet")
  final String title;

  /// Subtitle text displayed (e.g., "Start uploading...")
  final String subtitle;

  /// Icon to display (defaults to video library outline)
  final IconData icon;

  /// Icon size
  final double iconSize;

  /// Icon color (uses theme colors if not specified)
  final Color? iconColor;

  const EmptyVideosState({
    super.key,
    required this.isDark,
    this.title = 'No videos yet',
    this.subtitle = 'Start uploading videos to see them here',
    this.icon = Icons.video_library_outlined,
    this.iconSize = 64,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ??
                  (isDark ? AppColors.cyan : AppColors.electricMagenta),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
