import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beat_that/constants/app_colors.dart';

/// A reusable widget that displays a permission denied error message.
/// 
/// This widget provides a sleek, modern UI for informing users that a specific
/// permission has been denied or not enabled. It's designed to match popular
/// applications' style and the Beat That app theme.
/// 
/// Example usage:
/// ```dart
/// PermissionDeniedCard(
///   icon: Icons.camera,
///   title: 'Camera Access Required',
///   body: 'To record videos, we need access to your camera.',
///   buttonText: 'Enable Permissions',
///   onButtonPressed: () => PermissionService.openAppSettings(),
/// )
/// ```
class PermissionDeniedCard extends StatelessWidget {
  /// The icon to display at the top of the card
  final IconData icon;

  /// The title text displayed prominently
  final String title;

  /// The body/description text
  final String body;

  /// The text for the action button
  final String buttonText;

  /// Callback function triggered when the button is pressed
  final VoidCallback onButtonPressed;

  /// Optional custom button color
  final Color? buttonColor;

  /// Optional custom icon color
  final Color? iconColor;

  const PermissionDeniedCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonText,
    required this.onButtonPressed,
    this.buttonColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (iconColor ?? AppColors.blue).withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    icon,
                    size: 48,
                    color: iconColor ?? AppColors.blue,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                ),
                const SizedBox(height: 12),

                // Body text
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 32),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onButtonPressed();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonText,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16,
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
