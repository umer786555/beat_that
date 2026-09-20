import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/constants/app_urls.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthLegalConsentSection extends StatelessWidget {
  const AuthLegalConsentSection({
    super.key,
    this.enabled = true,
  });

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

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 3,
        runSpacing: 6,
        children: [
          Text(
            'By creating an account, you agree to our',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          _LegalLinkButton(
            title: AppStrings.termsAndConditions,
            enabled: enabled,
            onPressed: () {
              openExternalPage(AppUrls.termsAndConditions);
            },
          ),
          Text(
            'and',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
              height: 1.4,
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
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.cyan,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}
