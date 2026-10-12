import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:beat_that/widgets/feed_grid_geometry.dart';
import 'package:flutter/material.dart';

/// Shimmer placeholder cards laid out like the Home and Explore video grids.
class FeedGridSkeletonSliver extends StatelessWidget {
  const FeedGridSkeletonSliver({
    super.key,
    required this.itemCount,
    this.padding = const EdgeInsets.fromLTRB(
      kFeedGridSpacing,
      kFeedGridSpacing,
      kFeedGridSpacing,
      0,
    ),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverSemantics(
      container: true,
      label: 'Loading videos',
      sliver: SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: kFeedGridDelegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: const BeatShimmerFill(),
            ),
            childCount: itemCount,
          ),
        ),
      ),
    );
  }
}
