import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/screens/settings/bloc/settings_bloc.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/delete_account_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeBloc>().state.themeMode.isDark;

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
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                subtitle: const Text(AppStrings.darkThemeDescription),
                onChanged: (_) {
                  HapticFeedback.mediumImpact();
                  context.read<ThemeBloc>().add(ToggleThemeEvent());
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.block_outlined,
                  color: isDark ? AppColors.cyan : AppColors.electricMagenta,
                ),
                title: const Text(AppStrings.blockedUsers),
                subtitle: const Text(AppStrings.blockedUsersDescription),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.pushNamed('blocked-users');
                },
              ),
            ),
            const SizedBox(height: 16),
            BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, state) {
                return Column(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.red,
                        ),
                        title: const Text(AppStrings.deleteAccount),
                        subtitle: const Text(
                          AppStrings.deleteAccountDescription,
                        ),
                        trailing: state.isDeletingAccount
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
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.logout,
                          color: isDark
                              ? AppColors.cyan
                              : AppColors.electricMagenta,
                        ),
                        title: const Text(AppStrings.logOut),
                        subtitle: const Text(AppStrings.logOutDescription),
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
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
