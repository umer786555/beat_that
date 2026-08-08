import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/user_profile_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConnectionListTile extends StatelessWidget {
  const ConnectionListTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  final UserProfileSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasProfileUrl =
        user.profileUrl != null && user.profileUrl!.isNotEmpty;
    final accent = isDark ? AppColors.cyan : AppColors.electricMagenta;

    return ListTile(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.45 : 0.9,
        ),
        backgroundImage: hasProfileUrl ? NetworkImage(user.profileUrl!) : null,
        child: hasProfileUrl ? null : Icon(Icons.person, color: accent),
      ),
      title: Text(
        user.username,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
