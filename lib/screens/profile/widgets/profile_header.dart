import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/bloc/follow_counts_cubit.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/screens/profile/widgets/profile_stat_tile.dart';

/// A reusable profile header widget displaying user info, profile picture, and stats.
///
/// This widget shows:
/// - Profile picture (circular and tappable)
/// - Username
/// - Following/Followers stat tiles (interactive with enhanced styling)
/// - Divider separator
///
/// All interactions are handled via callbacks to avoid tight coupling.
///
/// Usage:
/// ```dart
/// ProfileHeader(
///   profileUrl: state.profileUrl,
///   username: state.username,
///   isDark: isDark,
///   onProfilePictureTap: () { /* handle tap */ },
///   onFollowingTap: () { /* navigate to following */ },
///   onFollowersTap: () { /* navigate to followers */ },
/// )
/// ```
class ProfileHeader extends StatelessWidget {
  /// URL of the user's profile picture
  final String? profileUrl;

  /// Username to display
  final String? username;

  /// Whether dark mode is enabled
  final bool isDark;

  /// Callback triggered when profile picture is tapped
  final VoidCallback onProfilePictureTap;

  /// Callback triggered when "Following" stat is tapped
  final VoidCallback onFollowingTap;

  /// Callback triggered when "Followers" stat is tapped
  final VoidCallback onFollowersTap;

  const ProfileHeader({
    super.key,
    required this.profileUrl,
    required this.username,
    required this.isDark,
    required this.onProfilePictureTap,
    required this.onFollowingTap,
    required this.onFollowersTap,
  });

  /// Builds the profile picture widget with a solid outer ring
  Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onProfilePictureTap();
      },
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Solid outer ring
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
            // Inner content container
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.black : Colors.white,
              ),
              child: profileUrl != null && profileUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        profileUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.error_outline,
                            size: 44,
                            color: isDark
                                ? AppColors.cyan
                                : AppColors.electricMagenta,
                          );
                        },
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  AppColors.cyan.withValues(alpha: 0.2),
                                  AppColors.electricPurple.withValues(
                                      alpha: 0.2),
                                ]
                              : [
                                  AppColors.electricMagenta
                                      .withValues(alpha: 0.1),
                                  AppColors.cyan.withValues(alpha: 0.08),
                                ],
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 44,
                        color: isDark
                            ? AppColors.cyan.withValues(alpha: 0.7)
                            : AppColors.electricMagenta.withValues(
                                alpha: 0.6),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the username section
  Widget _buildUsernameSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username with improved typography
            Text(
              username ?? 'Beat That User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a stat tile using BlocBuilder for reactive updates
  Widget _buildStatTile({
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return ProfileStatTile(
      value: '$count',
      label: label,
      isDark: isDark,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture and Username Row with enhanced spacing
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfilePicture(),
                _buildUsernameSection(),
              ],
            ),
            const SizedBox(height: 28),
            // Stats row with larger tappable surfaces
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: BlocBuilder<FollowCountsCubit, FollowCountsState>(
                      builder: (context, followCountsState) {
                        return _buildStatTile(
                          label: 'Following',
                          count: followCountsState.following,
                          onTap: onFollowingTap,
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: BlocBuilder<FollowCountsCubit, FollowCountsState>(
                      builder: (context, followCountsState) {
                        return _buildStatTile(
                          label: 'Followers',
                          count: followCountsState.followers,
                          onTap: onFollowersTap,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Enhanced divider with gradient-like effect
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isDark
                            ? Colors.white
                            : Colors.black)
                        .withValues(alpha: 0),
                    (isDark
                            ? Colors.white
                            : Colors.black)
                        .withValues(alpha: 0.1),
                    (isDark
                            ? Colors.white
                            : Colors.black)
                        .withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
