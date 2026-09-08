import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class _OnboardingPalette {
  final Color accentColor;
  final Color panelColor;
  final Color borderColor;
  final Color shadowColor;
  final Color titleColor;
  final Color bodyColor;
  final Color buttonForegroundColor;
  final Color handleColor;

  const _OnboardingPalette({
    required this.accentColor,
    required this.panelColor,
    required this.borderColor,
    required this.shadowColor,
    required this.titleColor,
    required this.bodyColor,
    required this.buttonForegroundColor,
    required this.handleColor,
  });

  factory _OnboardingPalette.resolve(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? theme.colorScheme.primary
        : AppColors.electricMagenta;

    return _OnboardingPalette(
      accentColor: accentColor,
      panelColor: isDark ? AppColors.black : AppColors.white,
      borderColor: isDark
          ? AppColors.white.withValues(alpha: 0.14)
          : AppColors.borderVeryLightGray,
      shadowColor: isDark
          ? Colors.black.withValues(alpha: 0.42)
          : accentColor.withValues(alpha: 0.12),
      titleColor: isDark ? Colors.white : AppColors.electricMagenta,
      bodyColor: isDark ? AppColors.greyMedium : AppColors.textDarkGray,
      buttonForegroundColor: AppColors.white,
      handleColor: isDark
          ? Colors.white.withValues(alpha: 0.16)
          : AppColors.black.withValues(alpha: 0.12),
    );
  }
}

Future<bool> showAppOnboardingIntroSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String description,
  String primaryActionLabel = 'Show me',
}) async {
  final palette = _OnboardingPalette.resolve(context);

  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
                bottom: Radius.circular(28),
              ),
              color: palette.panelColor,
              border: Border.all(color: palette.borderColor),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowColor,
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.handleColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.accentColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: palette.accentColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: palette.titleColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.bodyColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.accentColor,
                            foregroundColor: palette.buttonForegroundColor,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(primaryActionLabel),
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
    },
  );

  return result ?? false;
}

class AppOnboarding extends StatefulWidget {
  final Widget child;

  const AppOnboarding({super.key, required this.child});

  @override
  State<AppOnboarding> createState() => _AppOnboardingState();
}

class _AppOnboardingState extends State<AppOnboarding> {
  late final ShowcaseView _showcaseView;

  @override
  void initState() {
    super.initState();
    _showcaseView = ShowcaseView.register(
      scope: widget.hashCode.toString(),
      blurValue: 1,
      autoPlayDelay: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _showcaseView.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) => widget.child);
  }
}

class AppOnboardingTarget extends StatelessWidget {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final Widget child;

  const AppOnboardingTarget({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _OnboardingPalette.resolve(context);

    return Showcase(
      key: targetKey,
      title: title,
      description: description,
      titleTextStyle: TextStyle(
        color: palette.accentColor,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      descTextStyle: TextStyle(
        color: palette.bodyColor,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: 0.1,
      ),
      tooltipBackgroundColor: palette.panelColor,
      targetBorderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

extension OnboardingFlowRequestX on OnboardingFlowRequest {
  List<GlobalKey> get showcaseKeys => steps.map((step) => step.key).toList();
}
