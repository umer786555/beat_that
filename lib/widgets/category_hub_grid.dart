import 'package:beat_that/models/category.dart';
import 'package:beat_that/widgets/hub_tile.dart';
import 'package:flutter/material.dart';

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 14,
  crossAxisSpacing: 14,
  childAspectRatio: 0.78,
);

/// Two-column sliver grid of [CategoryModel] tiles for the sports and gaming
/// hubs.
class CategoryHubGrid extends StatelessWidget {
  const CategoryHubGrid({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    this.wrapTile,
  });

  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onCategoryTap;

  /// Optionally wraps the tile at [index], e.g. to attach an onboarding
  /// target.
  final Widget Function(int index, Widget tile)? wrapTile;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = categories[index];
        final tile = HubTile(
          imageUrl: category.pathToImage,
          title: category.displayName,
          onTap: () => onCategoryTap(category),
        );

        return wrapTile?.call(index, tile) ?? tile;
      }, childCount: categories.length),
    );
  }
}

class CategoryHubGridSkeleton extends StatelessWidget {
  const CategoryHubGridSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) => const HubTileSkeleton(),
        childCount: itemCount,
      ),
    );
  }
}
