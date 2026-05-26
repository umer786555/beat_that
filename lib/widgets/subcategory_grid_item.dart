import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Subcategory item widget for displaying a single technique/action
class SubcategoryGridItem extends StatelessWidget {
  final String subcategoryName;
  final VoidCallback? onTap;

  const SubcategoryGridItem({
    super.key,
    required this.subcategoryName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.green.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                subcategoryName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
