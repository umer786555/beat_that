import 'dart:async';

import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_cubit.dart';
import 'package:beat_that/services/explore_feed_progress_store.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_playback/video_player_pool.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockPreferencesService extends Mock implements PreferencesService {}

class MockSupabaseService extends Mock implements SupabaseService {}

class MockVideoPlayerPool extends Mock implements VideoPlayerPool {}

void main() {
  setUpAll(() {
    registerFallbackValue(PauseReason.ad);
  });

  late MockSupabaseService supabaseService;
  late MockVideoPlayerPool pool;
  late StreamController<PlaybackProgress> activeProgress;

  SportVideo makeVideo(String id, {String? videoPath}) {
    return SportVideo(
      id: id,
      userId: 'user-$id',
      title: 'Video $id',
      description: '',
      videoPath: videoPath ?? '$id.mp4',
      thumbnailPath: '$id.jpg',
    );
  }

  List<SportVideo> makeVideos(int count) => [
    for (var i = 0; i < count; i++) makeVideo('v$i'),
  ];

  List<String> pathsOf(List<SportVideo> videos) => [
    for (final video in videos) video.videoPath,
  ];

  ExploreVideoFeedCubit buildCubit(
    List<SportVideo> videos, {
    int initialIndex = 0,
    bool hasMoreContent = false,
  }) {
    return ExploreVideoFeedCubit(
      initialVideos: videos,
      initialIndex: initialIndex,
      query: 'goal',
      nextOffset: videos.length,
      hasMoreContent: hasMoreContent,
    );
  }

  void stubSearch(Future<Map<String, dynamic>> Function() answer) {
    when(
      () => supabaseService.searchVideosByTitle(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        sportId: any(named: 'sportId'),
      ),
    ).thenAnswer((_) => answer());
  }

  PlaybackProgress playing(int seconds) => PlaybackProgress(
    position: Duration(seconds: seconds),
    duration: const Duration(seconds: 30),
    isPlaying: true,
  );

  /// Delivers queued progress events and pending async work.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    supabaseService = MockSupabaseService();
    pool = MockVideoPlayerPool();
    activeProgress = StreamController<PlaybackProgress>.broadcast();

    when(() => pool.activeProgress).thenAnswer((_) => activeProgress.stream);
    when(
      () => pool.slotFor(any()),
    ).thenReturn(ValueNotifier(const VideoSlot.loading()));
    when(
      () => supabaseService.updateCategoryVideoViewCount(
        linkedVideoId: any(named: 'linkedVideoId'),
      ),
    ).thenAnswer((_) async => {'success': true});

    GetIt.instance
      ..registerSingleton<PreferencesService>(MockPreferencesService())
      ..registerSingleton<SupabaseService>(supabaseService)
      ..registerSingleton<ExploreFeedProgressStore>(ExploreFeedProgressStore())
      ..registerSingleton<VideoPlayerPool>(pool);
  });

  tearDown(() async {
    await activeProgress.close();
    await GetIt.instance.reset();
  });

  group('pool lifecycle', () {
    test('initialize claims the pool and opens the window', () async {
      final videos = makeVideos(5);
      final cubit = buildCubit(videos, initialIndex: 1);

      await cubit.initialize();

      verifyInOrder([
        () => pool.claim(cubit),
        () => pool.setWindow(keys: pathsOf(videos), activeIndex: 1),
      ]);
      await cubit.close();
    });

    test('a page change moves the window', () async {
      final videos = makeVideos(5);
      final cubit = buildCubit(videos);
      await cubit.initialize();

      await cubit.onPageChanged(3);

      verify(() => pool.setWindow(keys: pathsOf(videos), activeIndex: 3));
      expect(cubit.state.currentIndex, 3);
      await cubit.close();
    });

    test('load-more sets the window again with the new videos', () async {
      final videos = makeVideos(2);
      final more = [makeVideo('v2'), makeVideo('v3')];
      stubSearch(
        () async => {'videos': more, 'nextOffset': 4, 'hasMore': false},
      );
      final cubit = buildCubit(videos, hasMoreContent: true);

      await cubit.initialize();

      verify(
        () =>
            pool.setWindow(keys: pathsOf([...videos, ...more]), activeIndex: 0),
      );
      await cubit.close();
    });

    test('a load-more that lands after close leaves the pool alone', () async {
      final loadMore = Completer<Map<String, dynamic>>();
      stubSearch(() => loadMore.future);
      final cubit = buildCubit(makeVideos(2), hasMoreContent: true);
      unawaited(cubit.initialize());
      await flush();

      await cubit.close();
      clearInteractions(pool);
      loadMore.complete({
        'videos': [makeVideo('v2')],
        'nextOffset': 3,
        'hasMore': false,
      });
      await flush();

      verifyNever(
        () => pool.setWindow(
          keys: any(named: 'keys'),
          activeIndex: any(named: 'activeIndex'),
        ),
      );
    });

    test('slotFor looks up the slot by videoPath', () async {
      final cubit = buildCubit(makeVideos(3));

      cubit.slotFor(2);

      verify(() => pool.slotFor('v2.mp4'));
      await cubit.close();
    });

    test('close releases the pool', () async {
      final cubit = buildCubit(makeVideos(3));
      await cubit.initialize();

      await cubit.close();

      verify(() => pool.release(cubit)).called(1);
    });

    test('ads add and remove the ad pause reason', () async {
      final cubit = buildCubit(makeVideos(3));

      cubit
        ..onAdShown()
        ..onAdClosed();

      verifyInOrder([
        () => pool.addPauseReason(PauseReason.ad),
        () => pool.removePauseReason(PauseReason.ad),
      ]);
      await cubit.close();
    });

    test('a covering route adds and removes the covered reason', () async {
      final cubit = buildCubit(makeVideos(3));

      cubit
        ..onRouteCovered()
        ..onRouteUncovered();

      verifyInOrder([
        () => pool.addPauseReason(PauseReason.covered),
        () => pool.removePauseReason(PauseReason.covered),
      ]);
      await cubit.close();
    });

    test('an empty videoPath shows the unavailable message', () async {
      final cubit = buildCubit([makeVideo('v0', videoPath: '')]);

      await cubit.initialize();

      expect(cubit.state.errorMessage, 'This video is unavailable.');
      await cubit.close();
    });

    test(
      'retryActiveVideo clears the error and retries the active key',
      () async {
        final cubit = buildCubit(makeVideos(3));
        await cubit.initialize();
        await cubit.onPageChanged(1);

        cubit.retryActiveVideo();

        verify(() => pool.retry('v1.mp4')).called(1);
        expect(cubit.state.errorMessage, isNull);
        await cubit.close();
      },
    );
  });

  group('view tracking', () {
    test('counts a view once the active video plays past 8s', () async {
      final cubit = buildCubit(makeVideos(3));
      await cubit.initialize();

      activeProgress
        ..add(playing(7))
        ..add(playing(8))
        ..add(playing(9));
      await flush();

      verify(
        () => supabaseService.updateCategoryVideoViewCount(linkedVideoId: 'v0'),
      ).called(1);
      await cubit.close();
    });

    test('does not count a paused video', () async {
      final cubit = buildCubit(makeVideos(3));
      await cubit.initialize();

      activeProgress.add(playing(9).copyWith(isPlaying: false));
      await flush();

      verifyNever(
        () => supabaseService.updateCategoryVideoViewCount(
          linkedVideoId: any(named: 'linkedVideoId'),
        ),
      );
      await cubit.close();
    });

    test('credits the view to the video swiped to', () async {
      final cubit = buildCubit(makeVideos(3));
      await cubit.initialize();
      activeProgress.add(playing(9));
      await flush();

      await cubit.onPageChanged(1);
      activeProgress.add(playing(9));
      await flush();

      verify(
        () => supabaseService.updateCategoryVideoViewCount(linkedVideoId: 'v1'),
      ).called(1);
      await cubit.close();
    });
  });
}
