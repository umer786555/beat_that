import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:flutter/material.dart';

class VideoOverlayActionButton extends StatelessWidget {
  const VideoOverlayActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor = AppColors.yellow,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        ) ??
        TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        );

    return InteractiveButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: accentColor,
              size: 22,
              shadows: [
                Shadow(
                  color: accentColor.withValues(alpha: 0.32),
                  blurRadius: 14,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}
