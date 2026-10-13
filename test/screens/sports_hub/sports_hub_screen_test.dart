import 'dart:async';

import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/sports_hub/sports_hub_screen.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/app_onboarding.dart';
import 'package:beat_that/services/onboarding_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/widgets/hub_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

class MockOnboardingService extends Mock implements OnboardingService {}

class FakeBuildContext extends Fake implements BuildContext {}

class FakeOnboardingFlowRequest extends Fake implements OnboardingFlowRequest {}

CategoryModel sport(String name) => CategoryModel(
  id: name,
  name: name.toLowerCase(),
  displayName: name,
  subcategories: const [],
);

void main() {
  late MockSupabaseService supabaseService;
  late MockOnboardingService onboardingService;
  SportDetailsExtra? pushedExtra;

  setUpAll(() {
    registerFallbackValue(FakeBuildContext());
    registerFallbackValue(FakeOnboardingFlowRequest());
  });

  setUp(() {
    pushedExtra = null;
    supabaseService = MockSupabaseService();
    onboardingService = MockOnboardingService();
    when(
      () => onboardingService.startFlow(
        any(),
        any(),
        beforeStart: any(named: 'beforeStart'),
      ),
    ).thenAnswer((_) async => false);
    locator
      ..registerSingleton<SupabaseService>(supabaseService)
      ..registerSingleton<OnboardingService>(onboardingService);
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/sports-hub',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('previous page'),
          routes: [
            GoRoute(
              path: 'sports-hub',
              builder: (_, _) => const AppOnboarding(child: SportsHubScreen()),
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
    final sports = Completer<List<CategoryModel>>();
    when(() => supabaseService.getAllSports()).thenAnswer((_) => sports.future);

    await pumpScreen(tester);

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text(AppStrings.chooseASport), findsOneWidget);
    expect(find.byType(HubTileSkeleton), findsWidgets);

    sports.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'wraps the first sport for onboarding and starts the flow once loaded',
    (tester) async {
      when(
        () => supabaseService.getAllSports(),
      ).thenAnswer((_) async => [sport('Basketball'), sport('Tennis')]);

      await pumpScreen(tester);

      final target = tester.widget<AppOnboardingTarget>(
        find.byType(AppOnboardingTarget),
      );
      expect(target.title, AppStrings.sportsHubOnboardingTitle);
      expect(
        find.descendant(
          of: find.byType(AppOnboardingTarget),
          matching: find.byType(HubTile),
        ),
        findsOneWidget,
      );
      verify(
        () => onboardingService.startFlow(
          any(),
          any(),
          beforeStart: any(named: 'beforeStart'),
        ),
      ).called(1);
    },
  );

  testWidgets('opens sport details with the tapped sport', (tester) async {
    final tennis = sport('Tennis');
    when(
      () => supabaseService.getAllSports(),
    ).thenAnswer((_) async => [sport('Basketball'), tennis]);

    await pumpScreen(tester);
    await tester.tap(find.widgetWithText(HubTile, 'Tennis'));
    await tester.pumpAndSettle();

    expect(find.text('details'), findsOneWidget);
    expect(pushedExtra?.sport, same(tennis));
  });

  testWidgets('error Retry reloads and Go Back pops', (tester) async {
    var calls = 0;
    when(() => supabaseService.getAllSports()).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('network down');
      return [sport('Basketball')];
    });

    await pumpScreen(tester);

    expect(
      find.text(AppStrings.somethingWentWrongPleaseTryAgain),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(HubTile, 'Basketball'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('previous page'), findsOneWidget);
  });
}
