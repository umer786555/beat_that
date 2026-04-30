import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'dart:math';

/// A modern loading screen with an elegant animated loader.
/// 
/// Based on UX best practices for loading screens:
/// - Uses smooth, engaging animations for fast actions (2-10 seconds)
/// - Optionally shows percent-done indicator for longer waits (10+ seconds)
/// - Provides immediate visual feedback to reassure users
/// - Reduces perceived wait time with elegant animations
/// 
/// Design: Modern pulsing ring loader with animated accent dots
/// and cyberpunk aesthetic using electric magenta and cyan colors.
class MissileLoadingScreen extends StatefulWidget {
  /// Custom message to display to the user
  /// Example: "Loading your beat...", "Processing video...", "Preparing content..."
  final String? message;

  /// Show a percent-done progress indicator (0-100)
  /// Use for operations taking 10+ seconds
  /// If null or not provided, defaults to looped animation
  final int? progress;

  /// Custom background color (defaults to app theme background)
  final Color? backgroundColor;

  /// Custom accent color (defaults to electric magenta)
  final Color? accentColor;

  /// Speed multiplier for animation (1.0 = normal, higher = faster)
  final double animationSpeed;

  /// Show a shimmer effect in the background
  final bool showShimmer;

  const MissileLoadingScreen({
    super.key,
    this.message,
    this.progress,
    this.backgroundColor,
    this.accentColor,
    this.animationSpeed = 1.0,
    this.showShimmer = true,
  });

  @override
  State<MissileLoadingScreen> createState() => _MissileLoadingScreenState();
}

class _MissileLoadingScreenState extends State<MissileLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: Duration(
        milliseconds: (3000 / widget.animationSpeed).toInt(),
      ),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(
        milliseconds: (1500 / widget.animationSpeed).toInt(),
      ),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Dark background for dark theme, white for light theme
    final backgroundColor =
        widget.backgroundColor ??
        (isDarkMode ? const Color(0xFF0a0a0a) : Colors.white);
    final accentColor = widget.accentColor ?? AppColors.electricMagenta;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Animated gradient background
          if (widget.showShimmer)
            Positioned.fill(
              child: _buildShimmerBackground(isDarkMode),
            ),

          // Main loading content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated loader
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulsing rings
                      _buildPulsingRings(accentColor),
                      
                      // Rotating accent dots
                      _buildRotatingDots(accentColor),
                      
                      // Center glow (green)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.green.withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Custom message
                if (widget.message != null)
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

                const SizedBox(height: 24),

                // Progress indicator (if provided)
                if (widget.progress != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: _buildProgressIndicator(accentColor, isDarkMode),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingRings(Color accentColor) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final progress = _pulseController.value;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ring 1 - Expands and fades (light green to dark green)
            Container(
              width: 80 + (40 * progress),
              height: 80 + (40 * progress),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color.lerp(AppColors.greenLight, AppColors.greenDark, progress)
                      ?.withValues(alpha: (1 - progress) * 0.6) ??
                  AppColors.green,
                  width: 2,
                ),
              ),
            ),
            // Ring 2 - Secondary pulse (light green)
            Container(
              width: 60 + (50 * progress),
              height: 60 + (50 * progress),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.greenLight.withValues(
                    alpha: (sin(progress * pi) * 0.5 + 0.5) * 0.4,
                  ),
                  width: 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRotatingDots(Color accentColor) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        final rotation = _mainController.value * 2 * pi;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // 3 rotating dots (light green to dark green)
            for (int i = 0; i < 3; i++)
              Positioned(
                child: Transform.rotate(
                  angle: rotation + (i * (2 * pi / 3)),
                  child: Transform.translate(
                    offset: const Offset(0, -50),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                          AppColors.greenLight,
                          AppColors.greenDark,
                          (sin(rotation + i) * 0.5 + 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProgressIndicator(Color accentColor, bool isDarkMode) {
    final progress = (widget.progress ?? 0) / 100;
    
    return Column(
      children: [
        // Animated progress bar with light green to dark green gradient
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: (isDarkMode
                      ? AppColors.electricPurple
                      : AppColors.borderVeryLightGray)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (progress * 100).toInt(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.greenLight, AppColors.greenDark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: ((1 - progress) * 100).toInt().clamp(0, 100),
                  child: Container(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Percentage text
        Text(
          '${widget.progress}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerBackground(bool isDarkMode) {
    return Container(
      color: isDarkMode ? const Color(0xFF0a0a0a) : Colors.white,
    );
  }
}
