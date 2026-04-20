import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Custom SnackBar with leading icon and configurable styling
class CustomSnackBar extends StatelessWidget {
  final String message;
  final IconData? leadingIcon;
  final Color iconColor;
  final Color backgroundColor;
  final Color textColor;
  final Duration duration;
  final VoidCallback? onDismissed;

  const CustomSnackBar({
    super.key,
    required this.message,
    this.leadingIcon,
    this.iconColor = AppColors.black,
    this.backgroundColor = AppColors.white,
    this.textColor = AppColors.black,
    this.duration = const Duration(seconds: 3),
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Content
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, color: iconColor, size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show a custom snackbar
void showCustomSnackBar(
  BuildContext context, {
  required String message,
  IconData? leadingIcon,
  Color iconColor = AppColors.black,
  Color backgroundColor = AppColors.white,
  Color textColor = AppColors.black,
  Duration duration = const Duration(seconds: 3),
  SnackBarBehavior behavior = SnackBarBehavior.floating,
  EdgeInsets margin = const EdgeInsets.all(16),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: CustomSnackBar(
        message: message,
        leadingIcon: leadingIcon,
        iconColor: iconColor,
        backgroundColor: backgroundColor,
        textColor: textColor,
        duration: duration,
      ),
      backgroundColor: Colors.transparent,
      elevation: 3,
      duration: duration,
      behavior: behavior,
      margin: margin,
      padding: EdgeInsets.zero,
    ),
  );
}

/// Preset styles for common snackbar types

/// Show a success snackbar (green background with checkmark)
void showSuccessSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
}) {
  showCustomSnackBar(
    context,
    message: message,
    leadingIcon: Icons.check_circle,
    iconColor: AppColors.green,
    backgroundColor: AppColors.white,
    textColor: AppColors.black,
    duration: duration,
  );
}

/// Show an error snackbar (red background with error icon)
void showErrorSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
}) {
  showCustomSnackBar(
    context,
    message: message,
    leadingIcon: Icons.error_outline,
    iconColor: AppColors.red,
    backgroundColor: AppColors.white,
    textColor: AppColors.black,
    duration: duration,
  );
}

/// Show a warning snackbar (orange background with warning icon)
void showWarningSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
}) {
  showCustomSnackBar(
    context,
    message: message,
    leadingIcon: Icons.warning_amber,
    iconColor: AppColors.orangeDark,
    backgroundColor: AppColors.white,
    textColor: AppColors.black,
    duration: duration,
  );
}

/// Show an info snackbar (blue background with info icon)
void showInfoSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 3),
}) {
  showCustomSnackBar(
    context,
    message: message,
    leadingIcon: Icons.info_outline,
    iconColor: AppColors.blue,
    backgroundColor: AppColors.white,
    textColor: AppColors.black,
    duration: duration,
  );
}
