import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-body message for the home feed's error and empty states, with an
/// action button below it.
class HomeFeedMessage extends StatelessWidget {
  const HomeFeedMessage({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: iconColor),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(actionIcon),
            label: Text(actionLabel),
            onPressed: () {
              HapticFeedback.mediumImpact();
              onAction();
            },
          ),
        ],
      ),
    );
  }
}
