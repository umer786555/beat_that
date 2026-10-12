import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_bloc.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_event.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_state.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/hub_grid_loading_view.dart';
import 'package:beat_that/widgets/sport_grid_item.dart';
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
            title: 'Choose a sport first',
            description:
                'Tap a sport to see its techniques. Then choose the exact '
                'move, like a three-point shot or dunk, and attach your video.',
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

  static const _description =
      'Choose a sport, then the exact technique for your clip before you '
      'upload and compete.';

  final Locale locale;
  final GlobalKey firstSportCardOnboardingKey;
  final VoidCallback onLoaded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _SportsHubAppBar(),
      body: BlocConsumer<SportsHubBloc, SportsHubState>(
        listener: (context, state) {
          if (state is SportsHubLoaded && state.sports.isNotEmpty) {
            onLoaded();
          }
        },
        builder: (context, state) {
          return switch (state) {
            SportsHubLoading() => const HubGridLoadingView(
              appBarTitle: 'Sports',
              description: _description,
            ),

            SportsHubError() => ErrorScreen(
              message: state.message,
              primaryButtonText: 'Retry',
              primaryButtonCallback: () {
                context.read<SportsHubBloc>().add(
                  RetrySportsEvent(locale: locale),
                );
              },
              secondaryButtonText: 'Go Back',
              secondaryButtonCallback: () {
                context.pop();
              },
            ),

            SportsHubLoaded() => _LoadedSportsView(
              sports: state.sports,
              firstSportCardOnboardingKey: firstSportCardOnboardingKey,
            ),

            _ => const HubGridLoadingView(
              appBarTitle: 'Sports',
              description: _description,
            ),
          };
        },
      ),
    );
  }
}

class _SportsHubAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SportsHubAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(leading: const BackButton(), title: const Text('Sports'));
  }
}

class _LoadedSportsView extends StatelessWidget {
  const _LoadedSportsView({
    required this.sports,
    required this.firstSportCardOnboardingKey,
  });

  final List<dynamic> sports;
  final GlobalKey firstSportCardOnboardingKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          sliver: SliverToBoxAdapter(
            child: Text(
              _SportsHubView._description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final sport = sports[index];

              final card = SportGridItem(
                sport: sport,
                onTap: () {
                  HapticFeedback.lightImpact();

                  context.pushNamed(
                    'sport-details',
                    extra: SportDetailsExtra(sport: sport),
                  );
                },
              );

              if (index != 0) {
                return card;
              }

              return AppOnboardingTarget(
                targetKey: firstSportCardOnboardingKey,
                title: 'Choose a sport first',
                description:
                    'Tap a sport to open its techniques. Next, choose '
                    'the exact move, like a three-point shot or dunk, '
                    'and attach your video.',
                child: card,
              );
            }, childCount: sports.length),
          ),
        ),
      ],
    );
  }
}
