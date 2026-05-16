import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget to display thumbnail loading error with retry functionality
class ThumbnailErrorWidget extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const ThumbnailErrorWidget({
    required this.isDark,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onRetry();
      },
      child: Container(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to retry',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
