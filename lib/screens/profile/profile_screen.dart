import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:beat_that/screens/profile/connections/bloc/profile_connections_bloc.dart';
import 'package:beat_that/screens/profile/widgets/empty_videos_state.dart';
import 'package:beat_that/screens/profile/widgets/profile_header.dart';
import 'package:beat_that/screens/profile/widgets/profile_videos_grid.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int _profileOnboardingVersion = 1;

  final OnboardingService _onboardingService = locator<OnboardingService>();
  final _onboardingSteps = _ProfileOnboardingSteps();
  bool _hasAttemptedProfileOnboarding = false;

  @override
  void initState() {
    super.initState();
    // The bloc outlives this screen, so it may already be loaded; in that case
    // the listener below never fires and the tour has to be started here.
    if (context.read<ProfileBloc>().state is ProfileLoaded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybePresentProfileOnboarding(),
      );
    }
  }

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
        steps: _onboardingSteps.all,
      ),
      beforeStart: (context) => showAppOnboardingIntroSheet(
        context,
        icon: Icons.person_rounded,
        title: AppStrings.profileOnboardingIntroTitle,
        description: AppStrings.profileOnboardingIntroDescription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocPresentationListener<ProfileBloc, ProfilePresentationEvent>(
      listener: (context, event) {
        switch (event) {
          case ProfileSuccessMessageEvent(:final message):
            showSuccessSnackBar(context, message: message);
          case ProfileErrorMessageEvent(:final message):
            showErrorSnackBar(context, message: message);
        }
      },
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listenWhen: (previous, current) =>
            previous is! ProfileLoaded && current is ProfileLoaded,
        listener: (context, state) => _maybePresentProfileOnboarding(),
        builder: (context, state) {
          return switch (state) {
            ProfileLoaded() => _ProfileLoadedView(
              state: state,
              onboardingSteps: _onboardingSteps,
            ),
            ProfileError(:final message) => ErrorScreen(
              message: message,
              primaryButtonText: AppStrings.retry,
              primaryButtonCallback: () {
                context.read<ProfileBloc>().add(const LoadProfileEvent());
              },
            ),
            ProfileInitial() || ProfileLoading() => const BeatLoadingScreen(
              message: AppStrings.loadingYourProfile,
            ),
          };
        },
      ),
    );
  }
}

/// The showcase targets of the profile tour, defined once so the tour request
/// and the widgets they highlight share the same keys and copy.
class _ProfileOnboardingSteps {
  final picture = OnboardingStepData(
    key: GlobalKey(),
    title: AppStrings.profileOnboardingPictureTitle,
    description: AppStrings.profileOnboardingPictureDescription,
  );
  final stats = OnboardingStepData(
    key: GlobalKey(),
    title: AppStrings.profileOnboardingStatsTitle,
    description: AppStrings.profileOnboardingStatsDescription,
  );
  final settings = OnboardingStepData(
    key: GlobalKey(),
    title: AppStrings.profileOnboardingSettingsTitle,
    description: AppStrings.profileOnboardingSettingsDescription,
  );
  final sportsHub = OnboardingStepData(
    key: GlobalKey(),
    title: AppStrings.profileOnboardingSportsHubTitle,
    description: AppStrings.profileOnboardingSportsHubDescription,
  );

  List<OnboardingStepData> get all => [picture, stats, settings, sportsHub];
}

class _ProfileLoadedView extends StatelessWidget {
  final ProfileLoaded state;
  final _ProfileOnboardingSteps onboardingSteps;

  const _ProfileLoadedView({
    required this.state,
    required this.onboardingSteps,
  });

  Future<void> _refresh(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final bloc = context.read<ProfileBloc>()..add(const LoadProfileEvent());
    await bloc.stream.firstWhere(
      (state) => state is! ProfileLoaded || !state.isRefreshing,
      orElse: () => bloc.state,
    );
  }

  void _openConnections(BuildContext context, String connectionType) {
    GoRouter.of(context).pushNamed(
      'profile-connections',
      extra: ProfileConnectionsExtra(connectionType: connectionType),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeBloc>().state.themeMode.isDark;

    return Scaffold(
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
          _OnboardingTarget(
            step: onboardingSteps.settings,
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
        onRefresh: () => _refresh(context),
        child: CustomScrollView(
          slivers: [
            ProfileHeader(
              profileUrl: state.profileUrl,
              username: state.username,
              isDark: isDark,
              isUploadingProfileImage: state.isUploadingProfileImage,
              profilePictureOnboardingStep: onboardingSteps.picture,
              statsOnboardingStep: onboardingSteps.stats,
              onProfilePictureTap: () {
                context.read<ProfileBloc>().add(const AddProfileImageEvent());
              },
              onFollowingTap: () =>
                  _openConnections(context, ProfileConnectionsType.following),
              onFollowersTap: () =>
                  _openConnections(context, ProfileConnectionsType.followers),
            ),
            if (state.myVideos.isEmpty)
              EmptyVideosState(isDark: isDark)
            else
              ProfileVideosGrid(
                videos: state.myVideos,
                isDark: isDark,
                deletingVideoId: state.deletingVideoId,
                onVideoDeleteConfirmed: (videoId) {
                  context.read<ProfileBloc>().add(
                    DeleteVideoEvent(videoId: videoId),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: _OnboardingTarget(
        step: onboardingSteps.sportsHub,
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.mediumImpact();
            GoRouter.of(context).pushNamed('upload-category');
          },
          backgroundColor: isDark ? AppColors.cyan : AppColors.electricMagenta,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: const Icon(Icons.sports_cricket),
          label: const Text(AppStrings.sportsHub),
          tooltip: AppStrings.browseSports,
        ),
      ),
    );
  }
}

class _OnboardingTarget extends StatelessWidget {
  final OnboardingStepData step;
  final Widget child;

  const _OnboardingTarget({required this.step, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppOnboardingTarget(
      targetKey: step.key,
      title: step.title,
      description: step.description,
      child: child,
    );
  }
}
