import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:beat_that/widgets/feed_grid_skeleton_sliver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSkeleton({required int itemCount}) {
    return MaterialApp(
      home: Center(
        // Narrow enough that every card is laid out without scrolling.
        child: SizedBox(
          width: 200,
          child: CustomScrollView(
            slivers: [FeedGridSkeletonSliver(itemCount: itemCount)],
          ),
        ),
      ),
    );
  }

  group('FeedGridSkeletonSliver', () {
    testWidgets('renders itemCount shimmer cards', (tester) async {
      await tester.pumpWidget(buildSkeleton(itemCount: 6));

      expect(find.byType(BeatShimmerFill), findsNWidgets(6));
    });

    testWidgets('is labelled for screen readers', (tester) async {
      await tester.pumpWidget(buildSkeleton(itemCount: 2));

      expect(find.bySemanticsLabel('Loading videos'), findsOneWidget);
    });
  });
}
