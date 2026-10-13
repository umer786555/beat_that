import 'dart:async';

import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/gaming_hub/gaming_hub_screen.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/widgets/hub_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

const _valorant = CategoryModel(
  id: 'valorant',
  name: 'valorant',
  displayName: 'Valorant',
  subcategories: [],
);

void main() {
  late MockSupabaseService supabaseService;
  SportDetailsExtra? pushedExtra;

  setUp(() {
    pushedExtra = null;
    supabaseService = MockSupabaseService();
    locator.registerSingleton<SupabaseService>(supabaseService);
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/gaming-hub',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('previous page'),
          routes: [
            GoRoute(
              path: 'gaming-hub',
              builder: (_, _) => const GamingHubScreen(),
            ),
            GoRoute(
              path: 'sport-details',
              name: 'sport-details',
              builder: (_, state) {
                pushedExtra = state.extra as SportDetailsExtra?;
                return const Text('details');
              },
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows one app bar and skeletons while loading', (tester) async {
    final games = Completer<List<CategoryModel>>();
    when(() => supabaseService.fetchGames()).thenAnswer((_) => games.future);

    await pumpScreen(tester);

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text(AppStrings.chooseAGame), findsOneWidget);
    expect(find.byType(HubTileSkeleton), findsWidgets);

    games.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('opens sport details with the tapped game', (tester) async {
    when(
      () => supabaseService.fetchGames(),
    ).thenAnswer((_) async => [_valorant]);

    await pumpScreen(tester);
    await tester.tap(find.widgetWithText(HubTile, 'Valorant'));
    await tester.pumpAndSettle();

    expect(find.text('details'), findsOneWidget);
    expect(pushedExtra?.sport, same(_valorant));
  });

  testWidgets('error shows generic copy and Retry reloads', (tester) async {
    var calls = 0;
    when(() => supabaseService.fetchGames()).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('network down');
      return [_valorant];
    });

    await pumpScreen(tester);

    expect(
      find.text(AppStrings.somethingWentWrongPleaseTryAgain),
      findsOneWidget,
    );
    expect(find.textContaining('network down'), findsNothing);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(HubTile, 'Valorant'), findsOneWidget);
  });

  testWidgets('error Go Back returns to the previous page', (tester) async {
    when(
      () => supabaseService.fetchGames(),
    ).thenThrow(Exception('network down'));

    await pumpScreen(tester);
    await tester.tap(find.text(AppStrings.goBack));
    await tester.pumpAndSettle();

    expect(find.text('previous page'), findsOneWidget);
  });
}
