import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';

class EmptyConnectionsWidget extends StatelessWidget {
  const EmptyConnectionsWidget({
    super.key,
    required this.title,
    required this.description,
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
    final isSearchState =
        icon == Icons.search_off_rounded ||
        title.toLowerCase().contains('match');
    final accent = isDark ? (accentColor ?? AppColors.cyan) : AppColors.cyan;
    final contrastAccent = AppColors.electricMagenta;
    final titleColor = isDark ? colorScheme.onSurface : AppColors.black;
    final descriptionColor = isDark
        ? colorScheme.onSurfaceVariant
        : AppColors.black.withValues(alpha: 0.72);
    final mutedColor = isDark
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.86)
        : AppColors.black.withValues(alpha: 0.56);
    final ringColor = isDark
        ? accent.withValues(alpha: 0.18)
        : accent.withValues(alpha: 0.10);
    final detailAccent = isDark ? accent : contrastAccent;
    final iconInnerColor = colorScheme.surface.withValues(
      alpha: isDark ? 0.92 : 1,
    );
    final helperText = isSearchState
        ? 'Try another name or username.'
        : 'This updates automatically when your connections change.';

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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ringColor,
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: iconInnerColor,
                              ),
                              child: Icon(icon, color: detailAccent, size: 30),
                            ),
                            if (!isSearchState)
                              Positioned(
                                right: 12,
                                bottom: 14,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: detailAccent,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: descriptionColor,
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        helperText,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedColor,
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
