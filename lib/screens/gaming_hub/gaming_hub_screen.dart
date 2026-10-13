import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/gaming_hub/bloc/gaming_hub_bloc.dart';
import 'package:beat_that/widgets/category_hub_grid.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class GamingHubScreen extends StatelessWidget {
  const GamingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GamingHubBloc()..add(const LoadGamingHubEvent()),
      child: const _GamingHubView(),
    );
  }
}

class _GamingHubView extends StatelessWidget {
  const _GamingHubView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GamingHubBloc, GamingHubState>(
      builder: (context, state) {
        if (state is GamingHubError) {
          return ErrorScreen(
            message: state.message,
            primaryButtonText: AppStrings.retry,
            primaryButtonCallback: () {
              context.read<GamingHubBloc>().add(const LoadGamingHubEvent());
            },
            secondaryButtonText: AppStrings.goBack,
            secondaryButtonCallback: () => context.pop(),
          );
        }

        return HubPage(
          title: AppStrings.chooseAGame,
          subtitle: AppStrings.gamingHubDescription,
          sliver: switch (state) {
            GamingHubLoaded() => CategoryHubGrid(
              categories: state.games,
              onCategoryTap: (game) {
                HapticFeedback.lightImpact();
                context.pushNamed(
                  'sport-details',
                  extra: SportDetailsExtra(sport: game),
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
