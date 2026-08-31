import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';


class UploadProgressOverlay extends StatelessWidget {
  final num progressPercent;
  final num sentBytes;
  final num totalBytes;
  final bool isUploading;
  final VoidCallback? onCancel; // Optional cancel action

  const UploadProgressOverlay({
    super.key,
    required this.progressPercent,
    required this.sentBytes,
    required this.totalBytes,
    required this.isUploading,
    this.onCancel,
  });

  String _formatBytes(num bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppColors.black;

    return IgnorePointer(
      ignoring: !isUploading,
      child: AnimatedOpacity(
        opacity: isUploading ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular progress indicator
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: progressPercent / 100,
                            strokeWidth: 4,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.electricMagenta,
                            ),
                            backgroundColor: isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppColors.greyLight.withValues(alpha: 0.2),
                          ),
                        ),
                        // Percentage text in center
                        Text(
                          '${progressPercent.toInt()}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Main heading
                  Text(
                    'Uploading',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // File size info
                  Text(
                    '${_formatBytes(sentBytes)} of ${_formatBytes(totalBytes)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Optional cancel button
                  if (onCancel != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.electricMagenta,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}