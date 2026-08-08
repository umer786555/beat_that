import 'package:flutter/material.dart';
import 'package:beat_that/models/sport.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Sport grid item widget displaying a single sport
class SportGridItem extends StatelessWidget {
  final Sport sport;
  final VoidCallback? onTap;

  const SportGridItem({super.key, required this.sport, this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image or icon
                if (sport.imageAssetPath != null)
                  Image.asset(
                    sport.imageAssetPath!,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.green.withValues(alpha: 0.2),
                          AppColors.green.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        sport.icon,
                        size: 48,
                        color: AppColors.green.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                
                // Gradient overlay for text readability
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      child: Text(
                        sport.displayName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
