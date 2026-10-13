import 'package:beat_that/widgets/feed_grid_geometry.dart';
import 'package:beat_that/widgets/feed_grid_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scrolls a lazily built grid to an off-screen card', (
    tester,
  ) async {
    const targetIndex = 57;
    final controller = ScrollController();
    final targetKey = GlobalKey();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: [
            for (var section = 0; section < 10; section++) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                sliver: SliverGrid(
                  gridDelegate: kFeedGridDelegate,
                  delegate: SliverChildBuilderDelegate((context, local) {
                    final index = section * 8 + local;
                    return ColoredBox(
                      key: index == targetIndex ? targetKey : null,
                      color: Colors.grey,
                      child: Text('video $index'),
                    );
                  }, childCount: 8),
                ),
              ),
              // Stands in for an ad of unknown height between sections.
              const SliverToBoxAdapter(child: SizedBox(height: 300)),
            ],
          ],
        ),
      ),
    );

    expect(find.text('video $targetIndex'), findsNothing);

    final reveal = revealFeedGridItem(
      controller: controller,
      targetKey: targetKey,
      estimatedOffset: estimateFeedGridOffset(
        index: targetIndex,
        gridWidth:
            tester.view.physicalSize.width / tester.view.devicePixelRatio,
      ),
      shouldContinue: () => true,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await reveal;

    final viewport = tester.getRect(find.byType(CustomScrollView));
    final card = tester.getRect(find.text('video $targetIndex'));
    expect(viewport.overlaps(card), isTrue);
  });

  testWidgets('does not scroll when told to stop', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          controller: controller,
          itemCount: 200,
          itemBuilder: (context, index) =>
              SizedBox(height: 100, child: Text('row $index')),
        ),
      ),
    );

    final reveal = revealFeedGridItem(
      controller: controller,
      targetKey: GlobalKey(),
      estimatedOffset: 5000,
      shouldContinue: () => false,
    );
    await tester.pump();
    await reveal;

    expect(controller.offset, 0);
  });

  group('estimateFeedGridOffset', () {
    test('headerOffset adds exactly its value', () {
      for (final index in [0, 10]) {
        final base = estimateFeedGridOffset(index: index, gridWidth: 400);
        final withHeader = estimateFeedGridOffset(
          index: index,
          gridWidth: 400,
          headerOffset: 100,
        );

        expect(withHeader, base + 100);
      }
    });

    test('index 2 starts one card row plus spacing down', () {
      // Card width (400 - 3 * 6) / 2 = 191; row = 191 / 0.64 + 6.
      expect(
        estimateFeedGridOffset(index: 2, gridWidth: 400),
        closeTo(304.4375, 1e-9),
      );
    });
  });
}
