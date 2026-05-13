import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// A stylish loading screen matching the app's cyberpunk aesthetic.
class BeatLoadingScreen extends StatefulWidget {
  /// Optional message to display below the loader
  final String? message;

  const BeatLoadingScreen({super.key, this.message});

  @override
  State<BeatLoadingScreen> createState() => _BeatLoadingScreenState();
}

class _BeatLoadingScreenState extends State<BeatLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode
        ? AppColors.electricPurple
        : AppColors.electricMagenta;
    final accentColor = isDarkMode ? AppColors.cyan : AppColors.electricMagenta;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [AppColors.black, AppColors.black.withValues(alpha: 0.95)]
                : [AppColors.white, AppColors.white.withValues(alpha: 0.98)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated loader
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background glow
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Outer rotating ring
                        Transform.rotate(
                          angle: _controller.value * 2 * 3.14159,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        // Middle rotating ring (counter-clockwise)
                        Transform.rotate(
                          angle: -_controller.value * 1.5 * 3.14159,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        // Inner rotating dots
                        Transform.rotate(
                          angle: _controller.value * 2 * 3.14159,
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Dot 1
                                Positioned(
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Dot 2
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryColor.withValues(
                                        alpha: 0.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Dot 3
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor.withValues(alpha: 0.6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Message
              if (widget.message != null) ...[
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
