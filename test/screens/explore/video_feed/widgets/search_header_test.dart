import 'package:beat_that/screens/explore/explore_filter_catalog.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/search_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Enough chips to overflow the 800 px test surface.
  final filterCatalog = ExploreFilterCatalog(
    sports: [
      for (var i = 1; i <= 16; i++)
        ExploreFilterOption(id: 'sport_$i', label: 'Sport option $i'),
    ],
    games: const [],
  );
  final lastOptionId = filterCatalog.allOptions.last.id;

  late TextEditingController textController;
  late ScrollController verticalController;

  setUp(() {
    textController = TextEditingController();
    verticalController = ScrollController(initialScrollOffset: 200);
  });

  tearDown(() {
    textController.dispose();
    verticalController.dispose();
  });

  Widget buildSubject({String? selectedFilterId}) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: verticalController,
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 300)),
            SliverToBoxAdapter(
              child: SearchHeader(
                controller: textController,
                filterCatalog: filterCatalog,
                selectedFilterId: selectedFilterId,
                onChanged: (_) {},
                onFilterChanged: (_) {},
                onClearQuery: () {},
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
  }

  ScrollPosition chipRowPosition(WidgetTester tester) {
    return tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(SearchHeader),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
  }

  group('SearchHeader', () {
    testWidgets(
      'scrolls the selected chip into view without moving the vertical list',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        expect(chipRowPosition(tester).pixels, 0);
        expect(verticalController.offset, 200);

        await tester.pumpWidget(buildSubject(selectedFilterId: lastOptionId));
        await tester.pumpAndSettle();

        expect(chipRowPosition(tester).pixels, greaterThan(0));
        expect(verticalController.offset, 200);
      },
    );

    testWidgets('keeps each chip\'s own state when the selection changes', (
      tester,
    ) async {
      final lastChip = find.ancestor(
        of: find.text(filterCatalog.allOptions.last.label),
        matching: find.byType(RawChip),
      );

      await tester.pumpWidget(buildSubject());
      final stateBefore = tester.state(lastChip);

      await tester.pumpWidget(buildSubject(selectedFilterId: lastOptionId));
      await tester.pumpAndSettle();

      expect(tester.state(lastChip), same(stateBefore));
    });

    testWidgets('scrolls back to the All chip when the filter is cleared', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpWidget(buildSubject(selectedFilterId: lastOptionId));
      await tester.pumpAndSettle();
      expect(chipRowPosition(tester).pixels, greaterThan(0));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(chipRowPosition(tester).pixels, 0);
      expect(verticalController.offset, 200);
    });
  });
}
