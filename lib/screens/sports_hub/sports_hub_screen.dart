import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_bloc.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_event.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_state.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/widgets/sport_grid_item.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/routes/app_router.dart';

/// Sports Hub screen - displays sports in a grid sorted by locale-based popularity
/// Fetches sports from Supabase and applies locale-based ordering
class SportsHubScreen extends StatefulWidget {
  const SportsHubScreen({super.key});

  @override
  State<SportsHubScreen> createState() => _SportsHubScreenState();
}

class _SportsHubScreenState extends State<SportsHubScreen> {
  static const int _sportsHubOnboardingVersion = 1;

  final OnboardingService _onboardingService = locator<OnboardingService>();
  final GlobalKey _firstSportCardOnboardingKey = GlobalKey();
  bool _hasAttemptedSportsHubOnboarding = false;

  Future<void> _maybePresentSportsHubOnboarding() async {
    if (_hasAttemptedSportsHubOnboarding || !mounted) {
      return;
    }

    _hasAttemptedSportsHubOnboarding = true;

    await _onboardingService.startFlow(
      context,
      OnboardingFlowRequest(
        flowId: OnboardingFlowIds.sportsHub,
        version: _sportsHubOnboardingVersion,
        steps: <OnboardingStepData>[
          OnboardingStepData(
            key: _firstSportCardOnboardingKey,
            title: 'Choose a sport first',
            description:
                'Tap a sport to see its techniques. Then choose the exact move, like a three-point shot or dunk, and attach your video.',
          ),
        ],
      ),
      beforeStart: _showSportsHubIntro,
    );
  }

  Future<bool> _showSportsHubIntro(BuildContext context) async {
    return showAppOnboardingIntroSheet(
      context,
      icon: Icons.sports_score_rounded,
      title: 'Pick a sport, then a technique',
      description:
          'Start with a sport, then pick the matching technique for your clip, like a three-point shot or dunk in basketball.',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the device platform locale for ordering sports by regional popularity
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;

    return BlocProvider(
      create: (context) =>
          SportsHubBloc()..add(FetchSportsEvent(locale: platformLocale)),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: false,
          title: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Beat That',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        body: BlocConsumer<SportsHubBloc, SportsHubState>(
          listener: (context, state) {
            if (state is SportsHubLoaded && state.sports.isNotEmpty) {
              _maybePresentSportsHubOnboarding();
            }
          },
          builder: (context, state) {
            if (state is SportsHubLoading) {
              return const BeatLoadingScreen(message: 'Loading sports...');
            }

            if (state is SportsHubError) {
              return ErrorScreen(
                message: state.message,
                primaryButtonText: 'Retry',
                primaryButtonCallback: () {
                  context.read<SportsHubBloc>().add(
                    RetrySportsEvent(locale: platformLocale),
                  );
                },
                secondaryButtonText: 'Go Back',
                secondaryButtonCallback: () {
                  Navigator.of(context).pop();
                },
              );
            }

            if (state is SportsHubLoaded) {
              final sports = state.sports;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Pick Your Challenge',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a sport, then the exact technique your video belongs to before you upload and compete.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: sports.length,
                        itemBuilder: (context, index) {
                          final sport = sports[index];
                          final sportCard = SportGridItem(
                            sport: sport,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              GoRouter.of(context).pushNamed(
                                'sport-details',
                                extra: SportDetailsExtra(sport: sport),
                              );
                            },
                          );

                          if (index == 0) {
                            return AppOnboardingTarget(
                              targetKey: _firstSportCardOnboardingKey,
                              title: 'Choose a sport first',
                              description:
                                  'Tap a sport to open its techniques. Next, choose the exact move, like a three-point shot or dunk, and attach your video.',
                              child: sportCard,
                            );
                          }

                          return sportCard;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            // Fallback to initial state
            return const BeatLoadingScreen(message: 'Loading sports...');
          },
        ),
      ),
    );
  }
}
