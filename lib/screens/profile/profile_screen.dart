import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/permission_denied_card.dart';

import 'package:beat_that/widgets/loading_screen.dart';
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
import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:beat_that/screens/profile/connections/bloc/profile_connections_bloc.dart';
import 'package:beat_that/screens/profile/widgets/profile_videos_grid.dart';
import 'package:beat_that/screens/profile/widgets/empty_videos_state.dart';
import 'package:beat_that/screens/profile/widgets/profile_header.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/service_locator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int _profileOnboardingVersion = 1;

  final OnboardingService _onboardingService = locator<OnboardingService>();
  final GlobalKey _profilePictureOnboardingKey = GlobalKey();
  final GlobalKey _statsOnboardingKey = GlobalKey();
  final GlobalKey _settingsOnboardingKey = GlobalKey();
  final GlobalKey _sportsHubOnboardingKey = GlobalKey();
  bool _hasAttemptedProfileOnboarding = false;

  Future<void> _maybePresentProfileOnboarding() async {
    if (_hasAttemptedProfileOnboarding || !mounted) {
      return;
    }

    _hasAttemptedProfileOnboarding = true;

    await _onboardingService.startFlow(
      context,
      OnboardingFlowRequest(
        flowId: OnboardingFlowIds.profileScreen,
        version: _profileOnboardingVersion,
        steps: <OnboardingStepData>[
          OnboardingStepData(
            key: _profilePictureOnboardingKey,
            title: 'Edit your profile',
            description:
                'Tap your profile image to add or change the photo people will see across Beat That.',
          ),
          OnboardingStepData(
            key: _statsOnboardingKey,
            title: 'Track your network',
            description:
                'Use Following and Followers to see your connections and jump into those lists.',
          ),
          OnboardingStepData(
            key: _settingsOnboardingKey,
            title: 'Open settings',
            description:
                'Manage theme, safety controls, and account actions from here.',
          ),
          OnboardingStepData(
            key: _sportsHubOnboardingKey,
            title: 'Go to Sports Hub',
            description:
                'Pick a sport, upload your best move, and compete on the leaderboard from Sports Hub.',
          ),
        ],
      ),
      beforeStart: _showProfileOnboardingIntro,
    );
  }

  Future<bool> _showProfileOnboardingIntro(BuildContext context) async {
    return showAppOnboardingIntroSheet(
      context,
      icon: Icons.person_rounded,
      title: 'This is your profile',
      description:
          'Profile is where you manage your identity, review your connections, and get back to the sports you want to compete in.',
    );
  }

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
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded) {
            _maybePresentProfileOnboarding();
          }
        },
        builder: (context, state) {
          final isDark = context.watch<ThemeBloc>().state.themeMode.isDark;
          if (state is CameraPermissionDenied) {
            return Scaffold(
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Text(
                  AppStrings.profile,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
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
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  centerTitle: true,
                  title: Text(
                    AppStrings.profile,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  actions: [
                    AppOnboardingTarget(
                      targetKey: _settingsOnboardingKey,
                      title: 'Open settings',
                      description:
                          'Manage theme, safety controls, and account actions from here.',
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          GoRouter.of(context).pushNamed('settings');
                        },
                      ),
                    ),
                  ],
                ),
                body: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    context.read<ProfileBloc>().add(const LoadProfileEvent());
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: CustomScrollView(
                    slivers: [
                      // Profile Header (Instagram-style)
                      ProfileHeader(
                        profileUrl: state.profileUrl,
                        username: state.username,
                        isDark: isDark,
                        profilePictureOnboardingStep: OnboardingStepData(
                          key: _profilePictureOnboardingKey,
                          title: 'Edit your profile',
                          description:
                              'Tap your profile image to add or change the photo people will see across Beat That.',
                        ),
                        statsOnboardingStep: OnboardingStepData(
                          key: _statsOnboardingKey,
                          title: 'Track your network',
                          description:
                              'Use Following and Followers to see your connections and jump into those lists.',
                        ),
                        onProfilePictureTap: () {
                          context.read<ProfileBloc>().add(
                            const AddProfileImageEvent(),
                          );
                        },
                        onFollowingTap: () {
                          GoRouter.of(context).pushNamed(
                            'profile-connections',
                            extra: ProfileConnectionsExtra(
                              connectionType: ProfileConnectionsType.following,
                            ),
                          );
                        },
                        onFollowersTap: () {
                          GoRouter.of(context).pushNamed(
                            'profile-connections',
                            extra: ProfileConnectionsExtra(
                              connectionType: ProfileConnectionsType.followers,
                            ),
                          );
                        },
                      ),
                      if (state.myVideo.isEmpty)
                        EmptyVideosState(isDark: isDark)
                      else
                        ProfileVideosGrid(
                          videos: state.myVideo,
                          isDark: isDark,
                          onVideoOpen: (videoPath) {},
                          onVideoDeleteConfirmed: (videoId) {},
                        ),
                    ],
                  ),
                ),
                floatingActionButton: AppOnboardingTarget(
                  targetKey: _sportsHubOnboardingKey,
                  title: 'Go to Sports Hub',
                  description:
                      'Pick a sport, upload your best move, and compete on the leaderboard from Sports Hub.',
                  child: FloatingActionButton.extended(
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
              ),
            );
          }

          // Loading state
          if (state is ProfileLoading) {
            return const BeatLoadingScreen(message: 'Loading your profile...');
          }

          // Error state
          if (state is ProfileError) {
            return ErrorScreen(
              message: state.message,
              primaryButtonText: 'Retry',
              primaryButtonCallback: () {
                context.read<ProfileBloc>().add(const LoadProfileEvent());
              },
            );
          }

          // Initial state or unknown state - show loading screen
          return const BeatLoadingScreen(message: 'Loading your profile...');
        },
      ),
    );
  }
}
