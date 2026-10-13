import 'package:beat_that/widgets/hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const page = HubPage(
    title: 'Choose a sport',
    subtitle: 'Pick the sport first.',
    sliver: SliverToBoxAdapter(child: Text('body')),
  );

  group('HubPage', () {
    testWidgets('renders the title, subtitle and sliver body', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: page));

      expect(find.text('Choose a sport'), findsOneWidget);
      expect(find.text('Pick the sport first.'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('back button pops the route by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(HubPage), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HubPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('back button does nothing when there is no route to pop', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: page));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(HubPage), findsOneWidget);
    });

    testWidgets('uses onBack when provided', (tester) async {
      var backs = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HubPage(
            title: 'Title',
            subtitle: 'Subtitle',
            sliver: const SliverToBoxAdapter(),
            onBack: () => backs++,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Back'));

      expect(backs, 1);
    });

    testWidgets('exposes the back button as a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(home: page));

      expect(
        tester.getSemantics(find.byTooltip('Back')),
        matchesSemantics(
          isButton: true,
          tooltip: 'Back',
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });
  });
}
