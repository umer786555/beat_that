import 'package:beat_that/widgets/permission_denied_card.dart';

import 'package:beat_that/bloc/follow_counts_cubit.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app_settings/app_settings.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:beat_that/screens/profile/connections/bloc/profile_connections_bloc.dart';
import 'package:beat_that/screens/profile/widgets/profile_video_grid_item.dart';
import 'package:beat_that/routes/app_router.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});
  final videoPickerService = locator<VideoPickerService>();

  @override
  Widget build(BuildContext context) {
    return BlocPresentationListener<ProfileBloc, ProfilePresentationEvent>(
      listener: (context, event) {
        switch (event) {
          case ProfileDeleteVideoSuccessEvent():
            showSuccessSnackBar(context, message: event.message);
          case ProfileDeleteVideoErrorEvent():
            showErrorSnackBar(context, message: event.message);
        }
      },
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          final isDark = context.watch<ThemeBloc>().state.themeMode.isDark;
          if (state is CameraPermissionDenied) {
            return Scaffold(
              appBar: AppBar(title: const Text(AppStrings.profile)),
              body: PermissionDeniedCard(
                icon: Icons.camera_alt,
                title: AppStrings.cameraAccessRequired,
                body: AppStrings.cameraPermissionBody,
                buttonText: AppStrings.openSettings,
                onButtonPressed: () {
                  AppSettings.openAppSettings(type: AppSettingsType.camera);
                },
              ),
            );
          }
          if (state is ProfileLoaded) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
              },
              child: Scaffold(
                appBar: AppBar(
                  title: const Text(AppStrings.profile),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {
                        GoRouter.of(context).pushNamed('settings');
                      },
                    ),
                  ],
                ),
                body: CustomScrollView(
                  slivers: [
                    // Profile Header (Instagram-style)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Profile Picture and Username Row
                            Row(
                              children: [
                                // Profile Picture Placeholder
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    context.read<ProfileBloc>().add(
                                      const AddProfileImageEvent(),
                                    );
                                  },
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.cyan
                                            : AppColors.electricMagenta,
                                        width: 2,
                                      ),
                                    ),
                                    child:
                                        state.profileUrl != null &&
                                            state.profileUrl!.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              state.profileUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    print(
                                                      'Image load failed: $error',
                                                    ); // This will show the actual error
                                                    return Icon(
                                                      Icons.error_outline,
                                                      size: 40,
                                                      color: isDark
                                                          ? AppColors.cyan
                                                          : AppColors
                                                                .electricMagenta,
                                                    );
                                                  },
                                            ),
                                          )
                                        : Icon(
                                            Icons.person,
                                            size: 40,
                                            color: isDark
                                                ? AppColors.cyan
                                                : AppColors.electricMagenta,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Username
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.username ?? 'Beat That User',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${state.thumbnails.length} ${state.thumbnails.length == 1 ? 'video' : 'videos'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Subscribers
                                BlocBuilder<
                                  FollowCountsCubit,
                                  FollowCountsState
                                >(
                                  builder: (context, followCountsState) {
                                    // Follow counts come from the shared
                                    // FollowCountsCubit so they stay in
                                    // sync after follow/unfollow actions
                                    // from other routes.
                                    return _ProfileStatTile(
                                      value: '${followCountsState.following}',
                                      label: 'Following',
                                      isDark: isDark,
                                      onTap: () {
                                        GoRouter.of(context).pushNamed(
                                          'profile-connections',
                                          extra: ProfileConnectionsExtra(
                                            connectionType:
                                                ProfileConnectionsType
                                                    .following,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                // Followers
                                BlocBuilder<
                                  FollowCountsCubit,
                                  FollowCountsState
                                >(
                                  builder: (context, followCountsState) {
                                    return _ProfileStatTile(
                                      value: '${followCountsState.followers}',
                                      label: 'Followers',
                                      isDark: isDark,
                                      onTap: () {
                                        GoRouter.of(context).pushNamed(
                                          'profile-connections',
                                          extra: ProfileConnectionsExtra(
                                            connectionType:
                                                ProfileConnectionsType
                                                    .followers,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Divider
                            Divider(
                              color: isDark
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state.thumbnails.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 64,
                                color: isDark
                                    ? AppColors.cyan
                                    : AppColors.electricMagenta,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No videos yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Start uploading videos to see them here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Videos Grid - balanced size with proper aspect ratio
                      SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final thumbnail = state.thumbnails[index];
                          return ProfileVideoGridItem(
                            thumbnail: thumbnail,
                            isDark: isDark,
                            onOpen: () {
                              HapticFeedback.mediumImpact();
                              GoRouter.of(context).pushNamed(
                                'edit-uploaded-video',
                                extra: PlayUploadedVideoExtra(
                                  videoPath: thumbnail.videoPath,
                                  shouldShowEditButtons: false,
                                ),
                              );
                            },
                            onDeleteConfirmed: (videoId) {
                              context.read<ProfileBloc>().add(
                                DeleteVideoEvent(videoId: videoId),
                              );
                            },
                          );
                        }, childCount: state.thumbnails.length),
                      ),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    GoRouter.of(context).pushNamed('sports-hub');
                  },
                  backgroundColor: isDark
                      ? AppColors.cyan
                      : AppColors.electricMagenta,
                  foregroundColor: isDark ? AppColors.white : AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  icon: const Icon(Icons.sports_cricket),
                  label: const Text('Sports Hub'),
                  tooltip: 'Browse Sports',
                ),
              ),
            );
          }

          // Loading state
          if (state is ProfileLoading) {
            return const BeatLoadingScreen(message: 'Loading your profile...');
          }

          // Error state
          if (state is ProfileError) {
            return Scaffold(
              appBar: AppBar(title: const Text(AppStrings.profile)),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: isDark
                          ? AppColors.cyan
                          : AppColors.electricMagenta,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error Loading Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        state.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ProfileBloc>().add(
                          const LoadProfileEvent(),
                        );
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Initial state or unknown state - show loading screen
          return const BeatLoadingScreen(message: 'Loading your profile...');
        },
      ),
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  const _ProfileStatTile({
    required this.value,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String value;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.cyan : AppColors.electricMagenta,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
