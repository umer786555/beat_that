import 'package:beat_that/models/category.dart';
import 'package:beat_that/widgets/category_hub_grid.dart';
import 'package:beat_that/widgets/hub_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget sliver) {
    return MaterialApp(home: CustomScrollView(slivers: [sliver]));
  }

  group('CategoryHubGrid', () {
    const categories = [
      CategoryModel(
        id: '1',
        name: 'a',
        displayName: 'Alpha',
        subcategories: [],
      ),
      CategoryModel(id: '2', name: 'b', displayName: 'Beta', subcategories: []),
    ];

    testWidgets('renders a tile per category and reports the tapped one', (
      tester,
    ) async {
      CategoryModel? tapped;

      await tester.pumpWidget(
        wrap(
          CategoryHubGrid(
            categories: categories,
            onCategoryTap: (category) => tapped = category,
          ),
        ),
      );

      expect(find.byType(HubTile), findsNWidgets(2));

      await tester.tap(find.widgetWithText(HubTile, 'Beta'));
      expect(tapped, same(categories[1]));
    });

    testWidgets('wraps tiles with wrapTile', (tester) async {
      await tester.pumpWidget(
        wrap(
          CategoryHubGrid(
            categories: categories,
            onCategoryTap: (_) {},
            wrapTile: (index, tile) => index == 0
                ? KeyedSubtree(key: const Key('first'), child: tile)
                : tile,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('first')),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing for an empty list', (tester) async {
      await tester.pumpWidget(
        wrap(CategoryHubGrid(categories: const [], onCategoryTap: (_) {})),
      );

      expect(find.byType(HubTile), findsNothing);
    });
  });

  group('CategoryHubGridSkeleton', () {
    testWidgets('renders the requested number of skeleton tiles', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const CategoryHubGridSkeleton(itemCount: 4)),
      );

      expect(find.byType(HubTileSkeleton), findsNWidgets(4));
    });
  });
}
