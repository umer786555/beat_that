import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  Widget buildFill({required bool disableAnimations}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: const BeatShimmerFill(),
      ),
    );
  }

  group('BeatShimmerFill', () {
    testWidgets('animates a shimmer by default', (tester) async {
      await tester.pumpWidget(buildFill(disableAnimations: false));

      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('is a static fill when reduced motion is on', (tester) async {
      await tester.pumpWidget(buildFill(disableAnimations: true));

      expect(find.byType(Shimmer), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BeatShimmerFill),
          matching: find.byType(ColoredBox),
        ),
        findsOneWidget,
      );
    });
  });
}
