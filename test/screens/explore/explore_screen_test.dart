import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/screens/explore/explore_screen.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabaseService;

  Widget buildTestApp() {
    return const MaterialApp(home: ExploreScreen());
  }

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    locator.registerSingleton<SupabaseService>(mockSupabaseService);
  });

  tearDown(() async {
    await locator.reset();
  });

  testWidgets(
    'sport-only refresh triggers haptic feedback and repeats search',
    (tester) async {
      final sportId = (sportOrderByLocale['en'] ?? const <String>[]).first;
      final sportLabel = getDisplayNameForSport(sportId);
      final platformCalls = <MethodCall>[];
      final result = {
        'videos': [
          {
            'id': 'video-1',
            'title': 'Baseline drill',
            'thumbnail_url': 'https://example.com/thumb1.jpg',
            'username': 'coach1',
            'view_count': 12,
            'average_rating': 4.4,
          },
        ],
        'totalCount': 1,
        'hasMore': false,
        'nextOffset': 1,
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            platformCalls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      when(
        () => mockSupabaseService.searchVideosByTitle(
          '',
          limit: 20,
          offset: 0,
          exactMatch: false,
          startsWithOnly: false,
          sportId: sportId,
        ),
      ).thenAnswer((_) async => result);

      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.text(sportLabel).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      expect(find.byType(VideoFeedCard), findsOneWidget);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final refreshFuture = refreshIndicator.onRefresh();

      await tester.pump();
      await refreshFuture;

      verify(
        () => mockSupabaseService.searchVideosByTitle(
          '',
          limit: 20,
          offset: 0,
          exactMatch: false,
          startsWithOnly: false,
          sportId: sportId,
        ),
      ).called(2);
      expect(
        platformCalls.any(
          (call) =>
              call.method == 'HapticFeedback.vibrate' &&
              call.arguments == 'HapticFeedbackType.mediumImpact',
        ),
        isTrue,
      );
    },
  );

  testWidgets('no-results state stays refreshable', (tester) async {
    const query = 'spin';
    final emptyResult = {
      'videos': <Map<String, dynamic>>[],
      'totalCount': 0,
      'hasMore': false,
      'nextOffset': 0,
    };

    when(
      () => mockSupabaseService.searchVideosByTitle(
        query,
        limit: 20,
        offset: 0,
        exactMatch: false,
        startsWithOnly: false,
        sportId: null,
      ),
    ).thenAnswer((_) async => emptyResult);

    await tester.pumpWidget(buildTestApp());
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('No videos found for "$query"'), findsOneWidget);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();

    verify(
      () => mockSupabaseService.searchVideosByTitle(
        query,
        limit: 20,
        offset: 0,
        exactMatch: false,
        startsWithOnly: false,
        sportId: null,
      ),
    ).called(2);
  });
}
