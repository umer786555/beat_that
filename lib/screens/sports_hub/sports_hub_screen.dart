import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_bloc.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_event.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_bloc/sports_hub_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/sport_grid_item.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/routes/app_router.dart';

/// Sports Hub screen - displays sports in a grid sorted by locale-based popularity
/// Fetches sports from Supabase and applies locale-based ordering
class SportsHubScreen extends StatelessWidget {
  const SportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the device platform locale for ordering sports by regional popularity
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;

    return BlocProvider(
      create: (context) => SportsHubBloc()
        ..add(FetchSportsEvent(locale: platformLocale)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sports Hub'),
          elevation: 0,
        ),
        body: BlocBuilder<SportsHubBloc, SportsHubState>(
          builder: (context, state) {
            if (state is SportsHubLoading) {
              return const BeatLoadingScreen(
                message: 'Loading sports...',
              );
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Popular Sports',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ordered by popularity in your region',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: sports.length,
                        itemBuilder: (context, index) {
                          final sport = sports[index];
                          return SportGridItem(
                            sport: sport,
                            onTap: () {
                              // Navigate to sport details screen using GoRouter
                              HapticFeedback.lightImpact();
                              GoRouter.of(context).pushNamed(
                                'sport-details',
                                extra: SportDetailsExtra(sport: sport),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            // Fallback to initial state
            return const BeatLoadingScreen(
              message: 'Loading sports...',
            );
          },
        ),
      ),
    );
  }
}
