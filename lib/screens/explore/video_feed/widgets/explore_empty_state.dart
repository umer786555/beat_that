import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ExploreEmptyState extends StatelessWidget {
  const ExploreEmptyState({
    required this.isDark,
    this.title = 'Search Videos',
    this.description =
        'Type a title or pick a sport to search for linked videos and see the results.',
    this.icon = Icons.search_rounded,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  });

  final bool isDark;
  final String title;
  final String description;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final defaultIconColor =
        isDark ? AppColors.cyan : AppColors.electricMagenta;
    final defaultBgColor = isDark
        ? AppColors.cyan.withValues(alpha: 0.14)
        : AppColors.electricMagenta.withValues(alpha: 0.10);

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor ?? defaultBgColor,
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? defaultIconColor,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
