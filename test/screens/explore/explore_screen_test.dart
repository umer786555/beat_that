import 'dart:async';

import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/screens/explore/explore_screen.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/explore_error_state.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/search_header.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:beat_that/widgets/feed_grid_skeleton_sliver.dart';
import 'package:beat_that/widgets/video_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabaseService;

  Map<String, dynamic> buildRandomExploreResult({
    List<dynamic> videos = const <dynamic>[],
    bool hasMore = false,
    Map<String, dynamic>? nextCursor,
    String seed = 'seed-1',
  }) {
    return {
      'videos': videos,
      'hasMore': hasMore,
      'nextCursor': nextCursor,
      'seed': seed,
    };
  }

  Widget buildTestApp() {
    return const MaterialApp(home: ExploreScreen());
  }

  // Four videos fill two grid rows without an ad slot, enough to scroll.
  List<SportVideo> buildVideos({int count = 4, int startIndex = 1}) {
    return [
      for (var i = startIndex; i < startIndex + count; i++)
        SportVideo(
          id: 'video-$i',
          userId: 'user-$i',
          title: 'Drill $i',
          description: '',
          videoPath: 'profiles/user-$i/videos/video$i.mp4',
          thumbnailPath: 'profiles/user-$i/thumbnails/thumb$i.jpg',
          thumbnailUrl: 'https://example.com/thumb$i.jpg',
          username: 'coach$i',
          viewCount: i,
          averageRating: 4,
        ),
    ];
  }

  ScrollPosition verticalScrollPosition(WidgetTester tester) {
    return tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
  }

  void stubFirstRandomPage(Future<Map<String, dynamic>> Function() answer) {
    when(
      () => mockSupabaseService.getRandomExploreVideos(
        limit: 20,
        seed: any(named: 'seed'),
        afterId: null,
        hasWrapped: false,
      ),
    ).thenAnswer((_) => answer());
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
          const SportVideo(
            id: 'video-1',
            userId: 'user-1',
            title: 'Baseline drill',
            description: '',
            videoPath: 'profiles/user-1/videos/video1.mp4',
            thumbnailPath: 'profiles/user-1/thumbnails/thumb1.jpg',
            thumbnailUrl: 'https://example.com/thumb1.jpg',
            username: 'coach1',
            viewCount: 12,
            averageRating: 4.4,
          ),
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
          sportId: sportId,
        ),
      ).thenAnswer((_) async => result);
      when(
        () => mockSupabaseService.getRandomExploreVideos(
          limit: 20,
          seed: any(named: 'seed'),
          afterId: null,
          hasWrapped: false,
        ),
      ).thenAnswer((_) async => buildRandomExploreResult());

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
        sportId: null,
      ),
    ).thenAnswer((_) async => emptyResult);
    when(
      () => mockSupabaseService.getRandomExploreVideos(
        limit: 20,
        seed: any(named: 'seed'),
        afterId: null,
        hasWrapped: false,
      ),
    ).thenAnswer((_) async => buildRandomExploreResult());

    await tester.pumpWidget(buildTestApp());
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('No matching videos for "$query"'), findsOneWidget);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refreshIndicator.onRefresh();

    verify(
      () => mockSupabaseService.searchVideosByTitle(
        query,
        limit: 20,
        offset: 0,
        sportId: null,
      ),
    ).called(2);
  });

  testWidgets('shows skeleton cards while the first search is pending', (
    tester,
  ) async {
    final pendingPage = Completer<Map<String, dynamic>>();
    stubFirstRandomPage(() => pendingPage.future);

    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(find.byType(FeedGridSkeletonSliver), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pendingPage.complete(buildRandomExploreResult());
    await tester.pumpAndSettle();
  });

  testWidgets('error state stays refreshable', (tester) async {
    when(
      () => mockSupabaseService.getRandomExploreVideos(
        limit: 20,
        seed: any(named: 'seed'),
        afterId: null,
        hasWrapped: false,
      ),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(ExploreErrorState), findsOneWidget);

    await tester.fling(
      find.byType(ExploreErrorState),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    verify(
      () => mockSupabaseService.getRandomExploreVideos(
        limit: 20,
        seed: any(named: 'seed'),
        afterId: null,
        hasWrapped: false,
      ),
    ).called(2);
  });

  testWidgets('header floats away on scroll and returns on a small drag down', (
    tester,
  ) async {
    stubFirstRandomPage(
      () async => buildRandomExploreResult(videos: buildVideos()),
    );

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(SearchHeader)).dy, 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Finders skip offstage widgets, so a fully hidden header isn't found.
    expect(find.byType(SearchHeader), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 50));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(SearchHeader)).dy, 0);
    expect(verticalScrollPosition(tester).pixels, greaterThan(0));
  });

  testWidgets('shows two skeleton cards while loading more', (tester) async {
    final secondPage = Completer<Map<String, dynamic>>();
    stubFirstRandomPage(
      () async => buildRandomExploreResult(
        videos: buildVideos(),
        hasMore: true,
        nextCursor: {'afterId': 'video-4', 'hasWrapped': false},
      ),
    );
    when(
      () => mockSupabaseService.getRandomExploreVideos(
        limit: 20,
        seed: any(named: 'seed'),
        afterId: 'video-4',
        hasWrapped: false,
      ),
    ).thenAnswer((_) => secondPage.future);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(FeedGridSkeletonSliver), findsNothing);

    // The first drag nears the end and starts the load; the second scrolls the
    // appended skeleton row into view.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(FeedGridSkeletonSliver),
        matching: find.byType(BeatShimmerFill),
      ),
      findsNWidgets(2),
    );

    secondPage.complete(buildRandomExploreResult());
    await tester.pumpAndSettle();

    expect(find.byType(FeedGridSkeletonSliver), findsNothing);
  });

  testWidgets('selecting a filter while scrolled down jumps to the top', (
    tester,
  ) async {
    final sportId = (sportOrderByLocale['en'] ?? const <String>[]).first;
    final sportLabel = getDisplayNameForSport(sportId);
    stubFirstRandomPage(
      () async => buildRandomExploreResult(videos: buildVideos()),
    );
    when(
      () => mockSupabaseService.searchVideosByTitle(
        '',
        limit: 20,
        offset: 0,
        sportId: sportId,
      ),
    ).thenAnswer(
      (_) async => {
        'videos': buildVideos(),
        'totalCount': 4,
        'hasMore': false,
        'nextOffset': 4,
      },
    );

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    // A small drag down brings the floating header back without
    // returning to the top.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 50));
    await tester.pumpAndSettle();

    expect(verticalScrollPosition(tester).pixels, greaterThan(0));

    await tester.tap(find.text(sportLabel).first);
    await tester.pump();

    expect(verticalScrollPosition(tester).pixels, 0);

    await tester.pumpAndSettle();
  });
}
