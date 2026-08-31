import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable stat tile widget that displays a count with a label.
class ProfileStatTile extends StatelessWidget {
  /// The stat value to display (e.g., "1.2K", "42")
  final String value;

  /// The label for the stat (e.g., "Followers", "Following")
  final String label;

  /// Whether dark mode is enabled
  final bool isDark;

  /// Callback when the tile is tapped
  final VoidCallback onTap;

  const ProfileStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = foregroundColor.withValues(alpha: 0.62);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: secondaryColor,
                    height: 1,
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
