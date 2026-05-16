import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// A modern loading screen with pulsing pill-shaped indicators.
/// Three indicators pulse in sequence, creating a rhythmic loading animation.
class BeatLoadingScreen extends StatefulWidget {
  /// Optional message to display below the loader
  final String? message;

  const BeatLoadingScreen({super.key, this.message});

  @override
  State<BeatLoadingScreen> createState() => _BeatLoadingScreenState();
}

class _BeatLoadingScreenState extends State<BeatLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  static const Duration _animationDuration = Duration(milliseconds: 1500);
  static const Duration _staggerDelay = Duration(milliseconds: 150);
  static const int _indicatorCount = 3;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.electricPurple : AppColors.electricMagenta;

    return Scaffold(
      body: Container(
        color: isDark ? AppColors.black : AppColors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing pill indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _indicatorCount,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _PulsingIndicator(
                      animation: _animationController,
                      delay: Duration(
                        milliseconds: _staggerDelay.inMilliseconds * index,
                      ),
                      color: primaryColor,
                    ),
                  ),
                ),
              ),

              // Message text
              if (widget.message != null) ...[
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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

/// A single pulsing pill-shaped indicator with staggered animation.
class _PulsingIndicator extends StatelessWidget {
  final AnimationController animation;
  final Duration delay;
  final Color color;

  const _PulsingIndicator({
    required this.animation,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Calculate elapsed time with delay offset (in milliseconds)
        final durationMs = animation.duration!.inMilliseconds.toDouble();
        final delayMs = delay.inMilliseconds.toDouble();
        final elapsedMs =
            (animation.value * durationMs - delayMs) % durationMs;
        final normalizedValue = (elapsedMs / durationMs).clamp(0.0, 1.0);

        // Pulse curve: ramp up to 1.0, then back to 0.3
        final opacityValue = normalizedValue < 0.5
            ? 0.3 + (normalizedValue * 2 * 0.7)
            : 0.3 + ((1 - normalizedValue) * 2 * 0.7);

        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(opacityValue),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}
