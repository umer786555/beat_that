import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/interactive_button.dart';

/// A bottom sheet widget for selecting video upload options
///
/// Provides options to either record a new video or upload from gallery
/// Features a sleek, modern design with premium visual hierarchy
class UploadVideoBottomSheet extends StatelessWidget {
  final VoidCallback onRecordVideoSelected;
  final VoidCallback onUploadFromGallerySelected;

  const UploadVideoBottomSheet({
    super.key,
    required this.onRecordVideoSelected,
    required this.onUploadFromGallerySelected,
  });

  // Design Constants
  static const BorderRadius _defaultBorderRadius = BorderRadius.all(
    Radius.circular(16),
  );
  static const EdgeInsets _optionPadding = EdgeInsets.symmetric(
    vertical: 20,
    horizontal: 20,
  );

  @override
  Widget build(BuildContext context) {
    final themeColors = _ThemeColors.from(context);

    return Container(
      decoration: BoxDecoration(
        color: themeColors.backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _buildDragHandle(themeColors.handleBarColor),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildHeader(context, themeColors),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildRecordVideoOption(context, themeColors),
                const SizedBox(height: 14),
                _buildUploadFromGalleryOption(context, themeColors),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// Build the drag handle indicator
  Widget _buildDragHandle(Color color) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Build the header section
  Widget _buildHeader(BuildContext context, _ThemeColors themeColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Video',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: themeColors.textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how to add your video',
                style: TextStyle(
                  fontSize: 14,
                  color: themeColors.subtitleColor,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Icon(Icons.close, color: themeColors.textColor, size: 24),
        ),
      ],
    );
  }

  /// Build the record video option
  Widget _buildRecordVideoOption(
    BuildContext context,
    _ThemeColors themeColors,
  ) {
    return _buildUploadOption(
      context,
      icon: Icons.videocam_rounded,
      title: 'Record Video',
      subtitle: 'Capture something new',
      accentColor: AppColors.electricMagenta,
      gradientColor: AppColors.electricMagenta.withValues(alpha: 0.1),
      themeColors: themeColors,
      onTap: () {
        HapticFeedback.mediumImpact();
        onRecordVideoSelected();
        Navigator.pop(context);
      },
    );
  }

  /// Build the upload from gallery option
  Widget _buildUploadFromGalleryOption(
    BuildContext context,
    _ThemeColors themeColors,
  ) {
    return _buildUploadOption(
      context,
      icon: Icons.photo_library_rounded,
      title: 'From Gallery',
      subtitle: 'Choose from your device',
      accentColor: AppColors.cyan,
      gradientColor: AppColors.cyan.withValues(alpha: 0.1),
      themeColors: themeColors,
      onTap: () {
        HapticFeedback.mediumImpact();
        onUploadFromGallerySelected();
        Navigator.pop(context);
      },
    );
  }

  /// Build individual upload option card
  Widget _buildUploadOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color gradientColor,
    required _ThemeColors themeColors,
    required VoidCallback onTap,
  }) {
    return InteractiveButton(
      borderRadius: _defaultBorderRadius,
      scaleDown: 0.96,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: _defaultBorderRadius,
          color: themeColors.cardBackgroundColor,
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gradient accent - subtle background
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradientColor,
                ),
              ),
            ),
            // Content
            Padding(
              padding: _optionPadding,
              child: Row(
                children: [
                  // Icon with background
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gradientColor,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, color: accentColor, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: themeColors.textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: themeColors.subtitleColor,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow accent
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class to manage theme-specific colors
class _ThemeColors {
  final Color backgroundColor;
  final Color textColor;
  final Color handleBarColor;
  final Color cardBackgroundColor;
  final Color subtitleColor;
  final bool isDarkMode;

  const _ThemeColors({
    required this.backgroundColor,
    required this.textColor,
    required this.handleBarColor,
    required this.cardBackgroundColor,
    required this.subtitleColor,
    required this.isDarkMode,
  });

  factory _ThemeColors.from(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return _ThemeColors(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      textColor: isDarkMode ? Colors.white : Colors.black,
      handleBarColor: isDarkMode
          ? colorScheme.onSurface.withValues(alpha: 0.25)
          : colorScheme.onSurface.withValues(alpha: 0.35),
      cardBackgroundColor: isDarkMode ? Colors.black : const Color(0xFFFAFAFA),
      subtitleColor: isDarkMode ? Colors.white : Colors.black,
      isDarkMode: isDarkMode,
    );
  }
}
