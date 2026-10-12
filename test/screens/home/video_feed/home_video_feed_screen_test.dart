import 'dart:async';

import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/screens/home/video_feed/presentation/home_video_feed_screen.dart';
import 'package:beat_that/services/ad_mob_consent_service.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_playback/video_player_pool.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockAdMobConsentService extends Mock implements AdMobConsentService {}

class MockAuthService extends Mock implements AuthService {}

class MockHomeFeedService extends Mock implements HomeFeedService {}

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
  late String sessionId;

  setUp(() {
    pool = MockVideoPlayerPool();
    activeProgress = StreamController<PlaybackProgress>.broadcast();
    routeObserver = RouteObserver<PageRoute<dynamic>>();
    navigatorKey = GlobalKey<NavigatorState>();

    final consentService = MockAdMobConsentService();
    when(() => consentService.canRequestAds).thenReturn(false);
    when(() => pool.activeProgress).thenAnswer((_) => activeProgress.stream);
    when(
      () => pool.slotFor(any()),
    ).thenReturn(ValueNotifier(const VideoSlot.loading()));

    final sessionStore = HomeVideoFeedSessionStore();
    sessionId = sessionStore.createSession(
      videos: const [
        SportVideo(
          id: 'v0',
          userId: 'user-0',
          title: 'Video v0',
          description: '',
          videoPath: 'v0.mp4',
          thumbnailPath: 'v0.jpg',
        ),
      ],
      nextCursor: const HomeFeedCursor.initial(),
      initialIndex: 0,
      hasMoreContent: false,
    );

    GetIt.instance
      ..registerSingleton<AdMobConsentService>(consentService)
      ..registerSingleton<AuthService>(MockAuthService())
      ..registerSingleton<HomeFeedService>(MockHomeFeedService())
      ..registerSingleton<PreferencesService>(MockPreferencesService())
      ..registerSingleton<SupabaseService>(MockSupabaseService())
      ..registerSingleton<HomeVideoFeedSessionStore>(sessionStore)
      ..registerSingleton<VideoPlayerPool>(pool)
      ..registerSingleton<RouteObserver<PageRoute<dynamic>>>(routeObserver);
  });

  tearDown(() async {
    await activeProgress.close();
    await GetIt.instance.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        home: HomeVideoFeedScreen(sessionId: sessionId, initialIndex: 0),
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
    verifyNever(() => pool.removePauseReason(PauseReason.covered));

    navigatorKey.currentState!.pop();
    await tester.pump();

    verify(() => pool.removePauseReason(PauseReason.covered)).called(1);
  });

  testWidgets('a bottom sheet does not pause the feed', (tester) async {
    await pumpScreen(tester);

    unawaited(
      showModalBottomSheet<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const SizedBox(height: 200),
      ),
    );
    await tester.pump();

    verifyNever(() => pool.addPauseReason(any()));
  });

  testWidgets('closing the screen releases the pool', (tester) async {
    await pumpScreen(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    verify(() => pool.release(any())).called(1);
  });
}
