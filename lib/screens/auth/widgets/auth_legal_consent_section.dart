import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/constants/app_urls.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthLegalConsentSection extends StatelessWidget {
  const AuthLegalConsentSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  static Future<void> openExternalPage(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !uri.hasScheme) {
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(-4, -3),
                child: Checkbox(
                  value: value,
                  onChanged: enabled
                      ? (checked) => onChanged(checked ?? false)
                      : null,
                  activeColor: AppColors.cyan,
                  checkColor: AppColors.black,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.38)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    AppStrings.authLegalConsentLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                _LegalLinkButton(
                  title: AppStrings.termsAndConditions,
                  enabled: enabled,
                  onPressed: () {
                    openExternalPage(AppUrls.termsAndConditions);
                  },
                ),
                Text(
                  '•',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
                _LegalLinkButton(
                  title: AppStrings.privacyPolicy,
                  enabled: enabled,
                  onPressed: () {
                    openExternalPage(AppUrls.privacyPolicy);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text(
              AppStrings.authLegalConsentHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLinkButton extends StatelessWidget {
  const _LegalLinkButton({
    required this.title,
    required this.onPressed,
    required this.enabled,
  });

  final String title;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cyan,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.cyan,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.cyan,
        ),
      ),
    );
  }
}
