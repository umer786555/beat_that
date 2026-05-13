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
    final secondaryTextColor = isDarkMode ? Colors.white : AppColors.black;

    return IgnorePointer(
      ignoring: !isUploading,
      child: AnimatedOpacity(
        opacity: isUploading ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: isDarkMode ? Colors.black87 : Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main heading
                  Text(
                    'Uploading Your Video',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Reassuring subtitle
                  Text(
                    'Please keep the app open',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Linear progress bar
                  SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: progressPercent / 100,
                      backgroundColor: isDarkMode
                          ? Colors.white.withOpacity(0.06)
                          : AppColors.greyLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.electricMagenta,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Percentage
                  Text(
                    '${progressPercent.toInt()}%',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.0,
                    ),
                  ),

                  const SizedBox(height: 44),

                  // File size info with better formatting
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.07)
                          : AppColors.greyLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Transfer Progress',
                          style: TextStyle(
                            fontSize: 16,
                            color: secondaryTextColor.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatBytes(sentBytes)} of ${_formatBytes(totalBytes)}',
                          style: TextStyle(
                            fontSize: 18,
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),


                  // Optional cancel button
                  if (onCancel != null)
                    ElevatedButton(
                      onPressed: onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.white : Colors.redAccent,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDarkMode ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}