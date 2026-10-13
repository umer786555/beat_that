import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:beat_that/widgets/hub_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, height: 180, child: child)),
      ),
    );
  }

  group('HubTile', () {
    testWidgets('shows title, subtitle and forward button', (tester) async {
      await tester.pumpWidget(
        wrap(
          HubTile(
            imageUrl: null,
            title: 'Sports',
            subtitle: 'Show us what you can do.',
            showForwardButton: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('Show us what you can do.'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
      expect(tester.widget<Text>(find.text('Sports')).maxLines, 1);
    });

    testWidgets('grid variant allows a two-line title and no arrow', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(HubTile(imageUrl: null, title: 'Basketball', onTap: () {})),
      );

      expect(tester.widget<Text>(find.text('Basketball')).maxLines, 2);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
    });

    testWidgets('ink well is the topmost hit target and reports taps', (
      tester,
    ) async {
      final previous = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = previous,
      );
      var taps = 0;

      await tester.pumpWidget(
        wrap(HubTile(imageUrl: null, title: 'Sports', onTap: () => taps++)),
      );
      // Fails if anything (image, gradient, text) is painted above the ink.
      await tester.tap(find.byType(InkWell));

      expect(taps, 1);
    });

    testWidgets('is announced as one labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          HubTile(
            imageUrl: null,
            title: 'Sports',
            subtitle: 'Show us what you can do.',
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(HubTile)),
        matchesSemantics(
          label: 'Sports. Show us what you can do.',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('shows a placeholder when there is no image', (tester) async {
      await tester.pumpWidget(
        wrap(HubTile(imageUrl: '', title: 'Sports', onTap: () {})),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('falls back to the placeholder when the image fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          HubTile(
            imageUrl: 'https://example.com/missing.png',
            title: 'Sports',
            onTap: () {},
          ),
        ),
      );
      // Network requests fail in widget tests, triggering the error builder.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });

  group('HubTileSkeleton', () {
    testWidgets('shimmers without text or tap target', (tester) async {
      await tester.pumpWidget(
        wrap(
          const HubTileSkeleton(showSubtitle: true, showForwardButton: true),
        ),
      );

      expect(find.byType(BeatShimmerFill), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
    });
  });
}
