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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 0.64,
                  ),
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
}
