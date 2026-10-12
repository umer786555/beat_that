import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:flutter/material.dart';

class HubGridLoadingView extends StatelessWidget {
  const HubGridLoadingView({
    super.key,
    required this.appBarTitle,
    required this.description,
    this.itemCount = 6,
  });

  final String appBarTitle;
  final String description;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(appBarTitle)),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            sliver: SliverToBoxAdapter(
              child: Text(
                description,
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
              delegate: SliverChildBuilderDelegate(
                (context, index) => const _HubGridLoadingCard(),
                childCount: itemCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubGridLoadingCard extends StatelessWidget {
  const _HubGridLoadingCard();

  static const _borderRadius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: _borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: const [
            BeatShimmerFill(),
            _ImageGradient(),
            _LoadingLabel(),
          ],
        ),
      ),
    );
  }
}

class _ImageGradient extends StatelessWidget {
  const _ImageGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.4, 0.65, 1.0],
        ),
      ),
    );
  }
}

class _LoadingLabel extends StatelessWidget {
  const _LoadingLabel();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Container(
          width: 88,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
