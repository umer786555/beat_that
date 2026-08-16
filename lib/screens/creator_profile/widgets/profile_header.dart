import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/screens/creator_profile/bloc/creator_profile_bloc.dart';
import 'package:beat_that/screens/creator_profile/widgets/profile_avatar.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.username,
    required this.profileUrl,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.isUpdatingFollow,
    required this.isDark,
  });

  final String username;
  final String? profileUrl;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool isUpdatingFollow;
  final bool isDark;

  Color get _accentColor =>
      isDark ? AppColors.cyan : AppColors.electricMagenta;

  Color get _dividerColor => isDark ? Colors.grey[700]! : Colors.grey[300]!;

  Color get _buttonBackgroundColor =>
      isFollowing ? Colors.transparent : _accentColor;

  Color get _buttonForegroundColor =>
      isFollowing ? _accentColor : Colors.white;

  String get _buttonLabel => isFollowing ? 'Following' : 'Follow';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              ProfileAvatar(
                profileUrl: profileUrl,
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isOwnProfile) ...[
                      const SizedBox(height: 12),
                      InteractiveButton(
                        onTap: isUpdatingFollow
                            ? null
                            : () {
                                context.read<CreatorProfileBloc>().add(
                                      const ToggleFollowStatusEvent(),
                                    );
                              },
                        enableHaptics: true,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _buttonBackgroundColor,
                            border: Border.all(color: _accentColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isUpdatingFollow
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                          _buttonForegroundColor,
                                        ),
                                  ),
                                )
                              : Text(
                                  _buttonLabel,
                                  style: TextStyle(
                                    color: _buttonForegroundColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: _dividerColor),
        ],
      ),
    );
  }
}
