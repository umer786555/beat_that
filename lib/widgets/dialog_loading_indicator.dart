import 'package:flutter/material.dart';
import 'dart:math';
import 'package:beat_that/constants/app_colors.dart';

/// A sleek, dialog-optimized loading indicator with animated rings and rotating dots.
/// Designed for clean integration with AlertDialogs.
/// 
/// Use in AlertDialog:
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (_) => AlertDialog(
///     content: DialogLoadingIndicator(message: 'Uploading...'),
///     contentPadding: EdgeInsets.zero,
///   ),
/// );
/// ```
class DialogLoadingIndicator extends StatefulWidget {
  final String? message;
  final double animationSpeed;

  const DialogLoadingIndicator({
    super.key,
    this.message,
    this.animationSpeed = 1.0,
  });

  @override
  State<DialogLoadingIndicator> createState() => _DialogLoadingIndicatorState();
}

class _DialogLoadingIndicatorState extends State<DialogLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late CurvedAnimation _mainCurved;
  late CurvedAnimation _pulseCurved;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: Duration(milliseconds: (3000 / widget.animationSpeed).toInt()),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(milliseconds: (1500 / widget.animationSpeed).toInt()),
      vsync: this,
    )..repeat();

    _mainCurved = CurvedAnimation(parent: _mainController, curve: Curves.easeInOutCirc);
    _pulseCurved = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCirc);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sleek animation container
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildPulsingRings(),
                _buildRotatingDots(),
              ],
            ),
          ),
          
          // Message (if provided)
          if (widget.message != null) ...[
            const SizedBox(height: 20),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPulsingRings() {
    return AnimatedBuilder(
      animation: _pulseCurved,
      builder: (context, _) {
        final progress = _pulseCurved.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring (expands and fades)
            Container(
              width: 50 + (20 * progress),
              height: 50 + (20 * progress),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.greenLight.withValues(alpha: 0.8 * (1 - progress)),
                  width: 1.5,
                ),
              ),
            ),
            // Inner ring (subtle)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.greenLight.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRotatingDots() {
    return AnimatedBuilder(
      animation: _mainCurved,
      builder: (context, _) {
        final rotation = _mainCurved.value * 2 * pi;
        final orbitRadius = 18.0;
        final dotRadius = 3.5;

        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (index) {
            final angle = (rotation + (index * 2 * pi / 3));
            final x = cos(angle) * orbitRadius;
            final y = sin(angle) * orbitRadius;
            final colorProgress = (sin(angle) + 1) / 2;

            return Transform.translate(
              offset: Offset(x, y),
              child: Container(
                width: dotRadius * 2,
                height: dotRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    AppColors.greenLight,
                    AppColors.greenDark,
                    colorProgress,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

