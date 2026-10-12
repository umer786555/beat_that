import 'package:beat_that/models/category.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/hub_grid_loading_view.dart';
import 'package:beat_that/widgets/sport_grid_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/screens/gaming_hub/bloc/gaming_hub_bloc.dart';
import 'package:go_router/go_router.dart';

class GamingHubScreen extends StatelessWidget {
  const GamingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GamingHubBloc()..add(LoadGamingHubEvent()),
      child: const _GamingHubView(),
    );
  }
}

class _GamingHubView extends StatelessWidget {
  const _GamingHubView();

  static const _description = 'Choose a game and start competing';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Gaming')),
      body: BlocBuilder<GamingHubBloc, GamingHubState>(
        builder: (context, state) {
          return switch (state) {
            GamingHubLoading() => const HubGridLoadingView(
              appBarTitle: 'Gaming',
              description: _description,
            ),
            GamingHubError() => ErrorScreen(message: state.message),
            GamingHubLoaded() => _LoadedView(games: state.games),
            _ => const HubGridLoadingView(
              appBarTitle: 'Gaming',
              description: _description,
            ),
          };
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.games});

  final List<CategoryModel> games;

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
              _GamingHubView._description,
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
              final game = games[index];

              return GameGridItem(
                game: game,
                onTap: () {
                  HapticFeedback.lightImpact();

                  HapticFeedback.lightImpact();

                  context.pushNamed(
                    'sport-details',
                    extra: SportDetailsExtra(sport: game),
                  );
                },
              );
            }, childCount: games.length),
          ),
        ),
      ],
    );
  }
}
