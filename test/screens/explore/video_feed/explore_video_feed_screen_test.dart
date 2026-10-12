import 'dart:async';

import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_route_extra.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_screen.dart';
import 'package:beat_that/services/ad_mob_consent_service.dart';
import 'package:beat_that/services/explore_feed_progress_store.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_playback/video_player_pool.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockAdMobConsentService extends Mock implements AdMobConsentService {}

class MockPreferencesService extends Mock implements PreferencesService {}

class MockSupabaseService extends Mock implements SupabaseService {}

class MockVideoPlayerPool extends Mock implements VideoPlayerPool {}

void main() {
  setUpAll(() {
    registerFallbackValue(PauseReason.ad);
  });

  late MockVideoPlayerPool pool;
  late StreamController<PlaybackProgress> activeProgress;
  late RouteObserver<PageRoute<dynamic>> routeObserver;
  late GlobalKey<NavigatorState> navigatorKey;
  late ValueNotifier<VideoSlot> slot;

  setUp(() {
    pool = MockVideoPlayerPool();
    activeProgress = StreamController<PlaybackProgress>.broadcast();
    routeObserver = RouteObserver<PageRoute<dynamic>>();
    navigatorKey = GlobalKey<NavigatorState>();
    slot = ValueNotifier(const VideoSlot.loading());

    final consentService = MockAdMobConsentService();
    when(() => consentService.canRequestAds).thenReturn(false);
    when(() => pool.activeProgress).thenAnswer((_) => activeProgress.stream);
    when(() => pool.slotFor(any())).thenReturn(slot);

    GetIt.instance
      ..registerSingleton<AdMobConsentService>(consentService)
      ..registerSingleton<PreferencesService>(MockPreferencesService())
      ..registerSingleton<SupabaseService>(MockSupabaseService())
      ..registerSingleton<ExploreFeedProgressStore>(ExploreFeedProgressStore())
      ..registerSingleton<VideoPlayerPool>(pool)
      ..registerSingleton<RouteObserver<PageRoute<dynamic>>>(routeObserver);
  });

  tearDown(() async {
    slot.dispose();
    await activeProgress.close();
    await GetIt.instance.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        home: const ExploreVideoFeedScreen(
          extra: ExploreVideoFeedExtra(
            videos: [
              SportVideo(
                id: 'v0',
                userId: 'user-0',
                title: 'Video v0',
                description: '',
                videoPath: 'v0.mp4',
                thumbnailPath: 'v0.jpg',
              ),
            ],
            initialIndex: 0,
            query: 'goal',
            nextOffset: 1,
            hasMoreContent: false,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('pushing a page pauses the feed and popping resumes it', (
    tester,
  ) async {
    await pumpScreen(tester);

    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ),
    );
    await tester.pump();
    verify(() => pool.addPauseReason(PauseReason.covered)).called(1);

    navigatorKey.currentState!.pop();
    await tester.pump();
    verify(() => pool.removePauseReason(PauseReason.covered)).called(1);
  });

  testWidgets('a loading slot shows a spinner on the current page', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a slot error shows retry, which retries the active video', (
    tester,
  ) async {
    await pumpScreen(tester);

    slot.value = const VideoSlot(status: VideoSlotStatus.error);
    await tester.pump();
    expect(find.text('Failed to load video. Tap to retry.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => pool.retry(any(), 'v0.mp4')).called(1);
  });

  testWidgets('a paused ready video shows the play indicator with chrome', (
    tester,
  ) async {
    slot.value = const VideoSlot(status: VideoSlotStatus.ready);
    await pumpScreen(tester);
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    await tester.tap(find.byType(PageView));
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('closing the screen releases the pool', (tester) async {
    await pumpScreen(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    verify(() => pool.release(any())).called(1);
  });
}
