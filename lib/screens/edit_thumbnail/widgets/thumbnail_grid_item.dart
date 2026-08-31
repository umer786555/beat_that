import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

class ThumbnailGridItem extends StatelessWidget {
  final Uint8List? thumbnailData;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isLoading;
  final Color? borderColor;
  final double? borderRadius;

  const ThumbnailGridItem({
    super.key,
    this.thumbnailData,
    required this.onTap,
    this.isSelected = false,
    this.isLoading = false,
    this.borderColor,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
              ? AppColors.electricMagenta
              : (borderColor ?? Theme.of(context).dividerColor),
            width: isSelected ? 1 : 1,
          ),
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius ?? 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedCrossFade(
                      firstChild: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      secondChild: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Image.memory(
                          thumbnailData!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      crossFadeState: isLoading ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 400),
                    );
                  },
                ),
              ),
            ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(borderRadius ?? 8),
                  ),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.electricMagenta,
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
