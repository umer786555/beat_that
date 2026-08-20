import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/constants/app_urls.dart';
import 'package:beat_that/screens/settings/bloc/settings_bloc.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/delete_account_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> _openExternalPage(
    BuildContext context,
    String url,
  ) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !uri.hasScheme) {
      return;
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return;
    }
  }

  Widget _buildNavigationTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    IconData trailingIcon = Icons.chevron_right,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        trailing: Icon(trailingIcon),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLegalLink(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        _openExternalPage(context, url);
      },
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(title),
    );
  }

  Widget _buildLegalFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          _buildLegalLink(
            context,
            title: AppStrings.privacyPolicy,
            url: AppUrls.privacyPolicy,
          ),
          Text(
            '•',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          _buildLegalLink(
            context,
            title: AppStrings.termsAndConditions,
            url: AppUrls.termsAndConditions,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeBloc>().state.themeMode.isDark;
    final accentColor = isDark ? AppColors.cyan : AppColors.electricMagenta;

    return BlocListener<SettingsBloc, SettingsState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        showErrorSnackBar(context, message: state.errorMessage!);
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            AppStrings.settings,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildSectionLabel(context, 'Preferences'),
                    Card(
                      child: SwitchListTile(
                        value: isDark,
                        activeThumbColor: AppColors.cyan,
                        activeTrackColor: AppColors.cyan.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        secondary: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: isDark ? AppColors.cyan : AppColors.electricMagenta,
                        ),
                        title: const Text(AppStrings.darkTheme),
                        onChanged: (_) {
                          HapticFeedback.mediumImpact();
                          context.read<ThemeBloc>().add(ToggleThemeEvent());
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel(context, 'Safety'),
                    _buildNavigationTile(
                      context: context,
                      icon: Icons.block_outlined,
                      iconColor: accentColor,
                      title: AppStrings.blockedUsers,
                      onTap: () {
                        context.pushNamed('blocked-users');
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionLabel(context, 'Account'),
                    BlocBuilder<SettingsBloc, SettingsState>(
                      builder: (context, state) {
                        final theme = Theme.of(context);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: ListTile(
                                leading: Icon(
                                  Icons.logout,
                                  color: isDark
                                      ? AppColors.cyan
                                      : AppColors.electricMagenta,
                                ),
                                title: const Text(AppStrings.logOut),
                                trailing: state.isLoggingOut
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right),
                                enabled: !state.isBusy,
                                onTap: state.isBusy
                                    ? null
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        context.read<SettingsBloc>().add(
                                          const LogoutRequested(),
                                        );
                                      },
                              ),
                            ),
                                  const SizedBox(height: 12),
                                  Card(
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      title: Text(
                                        AppStrings.deleteAccount,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      trailing: state.isDeletingAccount
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              Icons.chevron_right,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                      enabled: !state.isBusy,
                                      onTap: state.isBusy
                                          ? null
                                          : () {
                                              HapticFeedback.selectionClick();
                                              showDialog<void>(
                                                context: context,
                                                builder: (dialogContext) {
                                                  return DeleteAccountConfirmationDialog(
                                                    onCancel: () {
                                                      Navigator.of(dialogContext).pop();
                                                    },
                                                    onConfirm: () {
                                                      Navigator.of(dialogContext).pop();
                                                      context.read<SettingsBloc>().add(
                                                        const DeleteAccountRequested(),
                                                      );
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildLegalFooter(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
