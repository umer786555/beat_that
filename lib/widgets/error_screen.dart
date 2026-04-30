import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/interactive_button.dart';

/// A calming, elegant error screen that matches the Beat That aesthetic.
///
/// Design inspired by modern mobile apps (Instagram, TikTok, YouTube):
/// - Large prominent icon at top (120x120)
/// - Scrollable message area in center
/// - Fixed buttons anchored at bottom of screen
/// - Theme-aware design (dark/light mode)
/// - Soothing, non-alarming visual design
/// - Clean typography and spacing
///
/// Features:
/// - Customizable error message
/// - Optional primary and secondary buttons (only shown if text is provided)
/// - Message scrolls if needed; buttons always visible
/// - Content positioned naturally from top to bottom
///
/// Usage:
/// ```dart
/// ErrorScreen(
///   message: 'Unable to load video',
///   primaryButtonText: 'Retry',
///   primaryButtonCallback: () { /* retry */ },
///   secondaryButtonText: 'Go Back',
///   secondaryButtonCallback: () { /* go back */ },
/// )
/// ```
class ErrorScreen extends StatelessWidget {
  /// Error message displayed to the user
  final String message;

  /// Text for primary button (usually action-oriented)
  /// If null, button is hidden
  final String? primaryButtonText;

  /// Callback when primary button is pressed
  final VoidCallback? primaryButtonCallback;

  /// Text for secondary button (usually "Go Back", "Cancel", etc.)
  /// If null, button is hidden
  final String? secondaryButtonText;

  /// Callback when secondary button is pressed
  final VoidCallback? secondaryButtonCallback;

  /// Custom icon (defaults to error outline)
  final IconData? icon;

  /// Custom icon color (defaults to app theme)
  final Color? iconColor;

  const ErrorScreen({
    super.key,
    required this.message,
    this.primaryButtonText,
    this.primaryButtonCallback,
    this.secondaryButtonText,
    this.secondaryButtonCallback,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF0a0a0a) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Fixed icon at top
          Padding(
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            child: Icon(
              icon ?? Icons.error_outline,
              size: 100,
              color: iconColor ?? AppColors.red,
            ),
          ),

          // Scrollable text area in middle (centered)
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 100, 32, 100),
                child: Center(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Fixed button section at bottom
          if (primaryButtonText != null || secondaryButtonText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Primary button (main action - green)
                  if (primaryButtonText != null)
                    InteractiveButton(
                      onTap: primaryButtonCallback,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            primaryButtonText!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Spacing between buttons (if both exist)
                  if (primaryButtonText != null && secondaryButtonText != null)
                    const SizedBox(height: 20),

                  // Secondary button (alternative action - black outline)
                  if (secondaryButtonText != null)
                    InteractiveButton(
                      onTap: secondaryButtonCallback,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            secondaryButtonText!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
