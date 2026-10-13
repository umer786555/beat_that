import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_bloc.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_event.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_state.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/widgets/category_hub_grid.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SportsHubScreen extends StatefulWidget {
  const SportsHubScreen({super.key});

  @override
  State<SportsHubScreen> createState() => _SportsHubScreenState();
}

class _SportsHubScreenState extends State<SportsHubScreen> {
  static const _onboardingVersion = 1;

  final OnboardingService _onboardingService = locator<OnboardingService>();
  final GlobalKey _firstSportCardOnboardingKey = GlobalKey();

  bool _hasAttemptedOnboarding = false;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return BlocProvider(
      create: (_) => SportsHubBloc()..add(FetchSportsEvent(locale: locale)),
      child: _SportsHubView(
        locale: locale,
        firstSportCardOnboardingKey: _firstSportCardOnboardingKey,
        onLoaded: _maybePresentOnboarding,
      ),
    );
  }

  Future<void> _maybePresentOnboarding() async {
    if (_hasAttemptedOnboarding || !mounted) {
      return;
    }

    _hasAttemptedOnboarding = true;

    await _onboardingService.startFlow(
      context,
      OnboardingFlowRequest(
        flowId: OnboardingFlowIds.sportsHub,
        version: _onboardingVersion,
        steps: [
          OnboardingStepData(
            key: _firstSportCardOnboardingKey,
            title: AppStrings.sportsHubOnboardingTitle,
            description: AppStrings.sportsHubOnboardingDescription,
          ),
        ],
      ),
      beforeStart: _showOnboardingIntro,
    );
  }

  Future<bool> _showOnboardingIntro(BuildContext context) {
    return showAppOnboardingIntroSheet(
      context,
      icon: Icons.sports_score_rounded,
      title: 'Pick a sport, then a technique',
      description:
          'Start with a sport, then pick the matching technique for your '
          'clip, like a three-point shot or dunk in basketball.',
    );
  }
}

class _SportsHubView extends StatelessWidget {
  const _SportsHubView({
    required this.locale,
    required this.firstSportCardOnboardingKey,
    required this.onLoaded,
  });

  final Locale locale;
  final GlobalKey firstSportCardOnboardingKey;
  final VoidCallback onLoaded;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SportsHubBloc, SportsHubState>(
      listener: (context, state) {
        if (state is SportsHubLoaded && state.sports.isNotEmpty) {
          onLoaded();
        }
      },
      builder: (context, state) {
        if (state is SportsHubError) {
          return ErrorScreen(
            message: state.message,
            primaryButtonText: AppStrings.retry,
            primaryButtonCallback: () {
              context.read<SportsHubBloc>().add(
                RetrySportsEvent(locale: locale),
              );
            },
            secondaryButtonText: AppStrings.goBack,
            secondaryButtonCallback: () => context.pop(),
          );
        }

        return HubPage(
          title: AppStrings.chooseASport,
          subtitle: AppStrings.sportsHubDescription,
          sliver: switch (state) {
            SportsHubLoaded() => CategoryHubGrid(
              categories: state.sports,
              onCategoryTap: (sport) {
                HapticFeedback.lightImpact();
                context.pushNamed(
                  'sport-details',
                  extra: SportDetailsExtra(sport: sport),
                );
              },
              wrapTile: (index, tile) {
                if (index != 0) return tile;

                return AppOnboardingTarget(
                  targetKey: firstSportCardOnboardingKey,
                  title: AppStrings.sportsHubOnboardingTitle,
                  description: AppStrings.sportsHubOnboardingDescription,
                  child: tile,
                );
              },
            ),
            _ => const CategoryHubGridSkeleton(),
          },
        );
      },
    );
  }
}
