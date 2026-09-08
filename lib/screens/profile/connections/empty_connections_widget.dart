import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';

class EmptyConnectionsWidget extends StatelessWidget {
  const EmptyConnectionsWidget({
    super.key,
    required this.title,
    this.description = '',
    required this.icon,
    this.accentColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final normalizedTitle = title.toLowerCase();
    final isSearchState =
        icon == Icons.search_off_rounded || normalizedTitle.contains('match');
    final accent =
        accentColor ?? (isDark ? AppColors.cyan : AppColors.electricMagenta);
    final titleColor = isDark ? colorScheme.onSurface : AppColors.black;
    final descriptionColor = isDark
        ? colorScheme.onSurfaceVariant
        : AppColors.black.withValues(alpha: 0.72);
    final displayIcon = isSearchState
        ? Icons.manage_search_rounded
        : normalizedTitle.contains('blocked')
        ? Icons.block_rounded
        : normalizedTitle.contains('following')
        ? Icons.person_add_alt_1_rounded
        : normalizedTitle.contains('follower')
        ? Icons.people_alt_rounded
        : icon;
    final iconColor = isSearchState
        ? (isDark ? colorScheme.onSurfaceVariant : AppColors.greyDark)
        : accent;
    final helperText = description.isNotEmpty
        ? description
        : isSearchState
        ? 'Try another name or username'
        : 'When people connect with you, they will show up here';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        displayIcon,
                        size: isSearchState ? 56 : 64,
                        color: iconColor,
                        shadows: [
                          Shadow(
                            color: iconColor.withValues(
                              alpha: isDark ? 0.22 : 0.10,
                            ),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        helperText,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: descriptionColor,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
