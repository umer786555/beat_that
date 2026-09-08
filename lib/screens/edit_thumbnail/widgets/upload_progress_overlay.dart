import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';
class UploadProgressOverlay extends StatelessWidget {
  final num progressPercent;
  final num sentBytes;
  final num totalBytes;
  final bool isUploading;
  final VoidCallback? onCancel;

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

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final progress = (progressPercent / 100).clamp(0.0, 1.0);
    final percentage = progressPercent.clamp(0, 100).toInt();

    final surfaceColor = isDarkMode
        ? const Color(0xFF1C1C1E)
        : Colors.white;

    final primaryTextColor = isDarkMode
        ? Colors.white
        : AppColors.black;

    final secondaryTextColor = primaryTextColor.withValues(alpha: 0.55);

    final trackColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.07);

    return IgnorePointer(
      ignoring: !isUploading,
      child: AnimatedOpacity(
        opacity: isUploading ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Container(
          color: Colors.black.withValues(
            alpha: isDarkMode ? 0.68 : 0.52,
          ),
          alignment: Alignment.center,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  maxWidth: 360,
                ),
                padding: const EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  16,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.electricMagenta.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 23,
                            color: AppColors.electricMagenta,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Uploading video',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Please keep the app open',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Progress percentage + byte count
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_formatBytes(sentBytes)} / '
                          '${_formatBytes(totalBytes)}',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 7,
                        color: trackColor,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: progress.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: value,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.electricMagenta,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Bottom action
                    if (onCancel != null)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: onCancel,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            foregroundColor: secondaryTextColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel upload',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}