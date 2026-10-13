import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_bloc.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_event.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_state.dart';
import 'package:beat_that/screens/upload_category/models/upload_category.dart';
import 'package:beat_that/screens/upload_category/upload_category_screen.dart';
import 'package:beat_that/widgets/hub_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockUploadCategoryBloc
    extends MockBloc<UploadCategoryEvent, UploadCategoryState>
    implements UploadCategoryBloc {}

void main() {
  late MockUploadCategoryBloc bloc;

  setUpAll(() {
    registerFallbackValue(const FetchUploadCategoryImagesEvent());
  });

  setUp(() {
    bloc = MockUploadCategoryBloc();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    UploadCategoryState state,
  ) async {
    when(() => bloc.state).thenReturn(state);

    // Phone-sized surface so both 16:9 cards are laid out.
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/upload-category',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('previous page'),
          routes: [
            GoRoute(
              path: 'upload-category',
              builder: (_, _) => BlocProvider<UploadCategoryBloc>.value(
                value: bloc,
                child: const UploadCategoryScreen(),
              ),
            ),
            GoRoute(
              path: 'sports-hub',
              name: 'sports-hub',
              builder: (_, _) => const Text('sports hub'),
            ),
            GoRoute(
              path: 'gaming-hub',
              name: 'gaming-hub',
              builder: (_, _) => const Text('gaming hub'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        // Keeps the image shimmer static so pumpAndSettle can settle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final loaded = UploadCategoryLoaded(
    categories: [
      UploadCategory.fromImageUrl('sports.png')!,
      UploadCategory.fromImageUrl('gaming.png')!,
    ],
  );

  testWidgets('shows skeleton tiles while loading', (tester) async {
    await pumpScreen(tester, const UploadCategoryLoading());

    expect(find.text(AppStrings.chooseACategory), findsOneWidget);
    expect(find.byType(HubTileSkeleton), findsNWidgets(2));
    expect(find.byType(HubTile), findsNothing);
  });

  testWidgets('shows a tile per category', (tester) async {
    await pumpScreen(tester, loaded);

    expect(find.byType(HubTile), findsNWidgets(2));
    expect(find.text(AppStrings.sports), findsOneWidget);
    expect(find.text(AppStrings.gamingCategoryDescription), findsOneWidget);
  });

  testWidgets('opens the sports hub', (tester) async {
    await pumpScreen(tester, loaded);

    await tester.tap(find.widgetWithText(HubTile, AppStrings.sports));
    await tester.pumpAndSettle();

    expect(find.text('sports hub'), findsOneWidget);
  });

  testWidgets('opens the gaming hub', (tester) async {
    await pumpScreen(tester, loaded);

    await tester.tap(find.widgetWithText(HubTile, AppStrings.gaming));
    await tester.pumpAndSettle();

    expect(find.text('gaming hub'), findsOneWidget);
  });

  testWidgets('error retries through the bloc', (tester) async {
    await pumpScreen(
      tester,
      const UploadCategoryError(message: AppStrings.noUploadCategories),
    );

    expect(find.text(AppStrings.noUploadCategories), findsOneWidget);

    await tester.tap(find.text(AppStrings.retry));

    verify(
      () => bloc.add(any(that: isA<RetryUploadCategoryImagesEvent>())),
    ).called(1);
  });

  testWidgets('error Go Back returns to the previous page', (tester) async {
    await pumpScreen(
      tester,
      const UploadCategoryError(message: AppStrings.noUploadCategories),
    );

    await tester.tap(find.text(AppStrings.goBack));
    await tester.pumpAndSettle();

    expect(find.text('previous page'), findsOneWidget);
  });
}
