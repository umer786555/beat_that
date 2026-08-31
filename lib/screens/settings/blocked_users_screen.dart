import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/user_block.dart';
import 'package:beat_that/screens/creator_profile/widgets/profile_avatar.dart';
import 'package:beat_that/screens/settings/bloc/blocked_users_cubit.dart';
import 'package:beat_that/screens/profile/connections/empty_connections_widget.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  Widget _buildBlockedUserTile(
    BuildContext context,
    UserBlock user,
    bool isUnblocking,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.28)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.borderVeryLightGray;
    final secondaryTextColor = isDark
        ? colorScheme.onSurfaceVariant
        : AppColors.greyDark;
    final buttonBackgroundColor = isDark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFEEEEEE);
    final buttonBorderColor = isDark
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFE2E2E2);
    final buttonForegroundColor = isDark ? Colors.white : AppColors.black;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    profileUrl: user.blockedProfileUrl,
                    isDark: isDark,
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.blockedUsername,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Blocked',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InteractiveButton(
              onTap: isUnblocking
                  ? null
                  : () => context.read<BlockedUsersCubit>().unblockUser(user),
              enableHaptics: true,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: buttonBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: buttonBorderColor),
                ),
                child: isUnblocking
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            buttonForegroundColor,
                          ),
                        ),
                      )
                    : Text(
                        'Unblock',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: buttonForegroundColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BlockedUsersCubit()..loadBlockedUsers(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return BlocConsumer<BlockedUsersCubit, BlockedUsersState>(
            listenWhen: (previous, current) =>
                previous.feedbackMessage != current.feedbackMessage &&
                current.feedbackMessage != null,
            listener: (context, state) {
              final message = state.feedbackMessage;
              if (message == null) {
                return;
              }

              if (state.isFeedbackError) {
                showErrorSnackBar(context, message: message);
              } else {
                showSuccessSnackBar(context, message: message);
              }

              context.read<BlockedUsersCubit>().clearFeedback();
            },
            builder: (context, state) {
              if (state.isLoading && state.users.isEmpty) {
                return Scaffold(
                  appBar: AppBar(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    centerTitle: true,
                    title: Text(
                      'Blocked Users',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  body: const Center(child: CircularProgressIndicator()),
                );
              }

              return Scaffold(
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  centerTitle: true,
                  title: Text(
                    'Blocked Users',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                body: Builder(
                  builder: (context) {
                    if (state.screenErrorMessage != null && state.users.isEmpty) {
                      return ErrorScreen(
                        message: state.screenErrorMessage!,
                        primaryButtonText: 'Retry',
                        primaryButtonCallback: () {
                          context.read<BlockedUsersCubit>().loadBlockedUsers();
                        },
                      );
                    }

                    if (state.users.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () => context
                            .read<BlockedUsersCubit>()
                            .loadBlockedUsers(showLoadingState: false),
                        child: const EmptyConnectionsWidget(
                          title: 'No blocked users',
                          description:
                              'People you block will appear here so you can review them later.',
                          icon: Icons.block_outlined,
                          accentColor: Colors.red,
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => context
                          .read<BlockedUsersCubit>()
                          .loadBlockedUsers(showLoadingState: false),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: state.users.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Blocked accounts can\'t see your profile or interact with you while they stay on this list.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            );
                          }

                          final user = state.users[index - 1];
                          final isUnblocking = state.unblockingUserIds.contains(
                            user.id,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildBlockedUserTile(
                              context,
                              user,
                              isUnblocking,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}