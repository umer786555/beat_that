import 'dart:async';

import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/models/user_personal_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/auth_service.dart';

// Mock services
class MockHomeFeedService extends Mock implements HomeFeedService {}

class MockPreferencesService extends Mock implements PreferencesService {}

class MockSupabaseService extends Mock implements SupabaseService {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const HomeFeedCursor.initial());
    registerFallbackValue(UserPersonalProfile(username: 'fallback'));
  });

  late MockHomeFeedService mockHomeFeedService;
  late MockPreferencesService mockPreferencesService;
  late MockSupabaseService mockSupabaseService;
  late MockAuthService mockAuthService;

  HomeBloc buildBloc() => HomeBloc(
    preferencesService: mockPreferencesService,
    supabaseService: mockSupabaseService,
    homeFeedService: mockHomeFeedService,
    authService: mockAuthService,
  );

  SportVideo makeVideo(
    String id, {
    String userId = 'user-1',
    String title = 'Test Video',
    String username = 'user1',
    String source = 'personalized',
    double averageRating = 4,
    int viewCount = 0,
  }) {
    return SportVideo(
      id: id,
      userId: userId,
      userVideoId: id,
      title: title,
      description: '',
      videoPath: '$id.mp4',
      thumbnailPath: '$id.jpg',
      thumbnailUrl: 'https://example.com/$id.jpg',
      username: username,
      viewCount: viewCount,
      averageRating: averageRating,
      source: source,
    );
  }

  Map<String, dynamic> page(
    List<SportVideo> videos, {
    HomeFeedCursor nextCursor = const HomeFeedCursor.initial(),
    bool hasMoreContent = true,
  }) => {
    'videos': videos,
    'nextCursor': nextCursor,
    'hasMoreContent': hasMoreContent,
  };

  void stubFeed(Map<String, dynamic> result, {HomeFeedCursor? cursor}) {
    when(
      () => mockHomeFeedService.getHomeFeedContinuation(
        cursor: cursor ?? any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubFeedFuture(
    HomeFeedCursor cursor,
    Future<Map<String, dynamic>> Function() answer,
  ) {
    when(
      () => mockHomeFeedService.getHomeFeedContinuation(
        cursor: cursor,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => answer());
  }

  const seedCursor = HomeFeedCursor(
    hasMoreFollowing: false,
    serverState: {'page': 1},
  );

  late List<SportVideo> sampleVideos;
  late FeedLoaded seeded;

  setUp(() {
    mockHomeFeedService = MockHomeFeedService();
    mockPreferencesService = MockPreferencesService();
    mockSupabaseService = MockSupabaseService();
    mockAuthService = MockAuthService();

    sampleVideos = [
      makeVideo(
        'video-1',
        userId: 'user-1',
        title: 'Test Video 1',
        username: 'user1',
        source: 'personalized',
        averageRating: 4.5,
        viewCount: 100,
      ),
      makeVideo(
        'video-2',
        userId: 'user-2',
        title: 'Test Video 2',
        username: 'user2',
        source: 'trending',
        averageRating: 4.0,
        viewCount: 50,
      ),
    ];
    seeded = FeedLoaded(videos: sampleVideos, nextCursor: seedCursor);
  });

  test('initial state is HomeInitial', () {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    expect(bloc.state, isA<HomeInitial>());
  });

  group('InitialEvent', () {
    final profile = UserPersonalProfile(username: 'tester');

    setUp(() {
      when(
        () => mockPreferencesService.clearUserProfile(),
      ).thenAnswer((_) async {});
      when(
        () => mockPreferencesService.saveUserProfile(any()),
      ).thenAnswer((_) async {});
      stubFeed(page(sampleVideos));
    });

    blocTest<HomeBloc, HomeState>(
      'loads the home feed for guests',
      setUp: () {
        when(() => mockAuthService.hasFullAccountAccess()).thenReturn(false);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InitialEvent()),
      expect: () => [const FeedLoading(), FeedLoaded(videos: sampleVideos)],
      verify: (_) {
        verify(() => mockPreferencesService.clearUserProfile()).called(1);
        verifyNever(() => mockSupabaseService.fetchUserPersonalProfile());
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: const HomeFeedCursor.initial(),
            limit: 24,
          ),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'saves the profile and loads the feed when signed in',
      setUp: () {
        when(() => mockAuthService.hasFullAccountAccess()).thenReturn(true);
        when(
          () => mockSupabaseService.fetchUserPersonalProfile(),
        ).thenAnswer((_) async => profile);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InitialEvent()),
      expect: () => [const FeedLoading(), FeedLoaded(videos: sampleVideos)],
      verify: (_) {
        verify(() => mockPreferencesService.clearUserProfile()).called(1);
        verify(() => mockPreferencesService.saveUserProfile(profile)).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits NoUserProfile and skips the feed when signed in without one',
      setUp: () {
        when(() => mockAuthService.hasFullAccountAccess()).thenReturn(true);
        when(
          () => mockSupabaseService.fetchUserPersonalProfile(),
        ).thenAnswer((_) async => null);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InitialEvent()),
      expect: () => [const NoUserProfile()],
      verify: (_) {
        verify(() => mockPreferencesService.clearUserProfile()).called(1);
        verifyNever(() => mockPreferencesService.saveUserProfile(any()));
        verifyNever(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits FeedError and skips the feed when the profile fetch throws',
      setUp: () {
        when(() => mockAuthService.hasFullAccountAccess()).thenReturn(true);
        when(
          () => mockSupabaseService.fetchUserPersonalProfile(),
        ).thenThrow(Exception('Profile error'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const InitialEvent()),
      expect: () => [const FeedError()],
      verify: (_) {
        verifyNever(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );
  });

  group('RefreshFeedEvent', () {
    blocTest<HomeBloc, HomeState>(
      'fetches the first page from the initial cursor',
      setUp: () => stubFeed(page(sampleVideos, nextCursor: seedCursor)),
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const RefreshFeedEvent()),
      expect: () => [
        const FeedLoading(),
        FeedLoaded(videos: sampleVideos, nextCursor: seedCursor),
      ],
      verify: (_) {
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: const HomeFeedCursor.initial(),
            limit: 24,
          ),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits an empty FeedLoaded when the first page is empty',
      setUp: () => stubFeed(page([], hasMoreContent: false)),
      build: buildBloc,
      act: (bloc) => bloc.add(const RefreshFeedEvent()),
      expect: () => [
        const FeedLoading(),
        const FeedLoaded(videos: [], hasMoreContent: false),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits [FeedLoading, FeedError] when the fetch throws',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('Network error'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RefreshFeedEvent()),
      expect: () => [const FeedLoading(), const FeedError()],
    );

    blocTest<HomeBloc, HomeState>(
      'drops an older first page superseded by a newer refresh',
      build: buildBloc,
      act: (bloc) async {
        final olderCompleter = Completer<Map<String, dynamic>>();
        final newerCompleter = Completer<Map<String, dynamic>>();
        final pending = [olderCompleter, newerCompleter];
        stubFeedFuture(
          const HomeFeedCursor.initial(),
          () => pending.removeAt(0).future,
        );

        bloc.add(const RefreshFeedEvent());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const RefreshFeedEvent());
        await Future<void>.delayed(Duration.zero);

        newerCompleter.complete(page(sampleVideos));
        await bloc.stream.firstWhere((state) => state is FeedLoaded);
        olderCompleter.complete(page([makeVideo('older')]));
        await Future<void>.delayed(Duration.zero);
      },
      // The second FeedLoading equals the first, so the bloc drops it.
      expect: () => [const FeedLoading(), FeedLoaded(videos: sampleVideos)],
    );

    blocTest<HomeBloc, HomeState>(
      'preserves video fields',
      setUp: () => stubFeed(page(sampleVideos)),
      build: buildBloc,
      act: (bloc) => bloc.add(const RefreshFeedEvent()),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos[0].id, equals('video-1'));
        expect(state.videos[0].username, equals('user1'));
        expect(state.videos[0].source, equals('personalized'));
        expect(state.videos[1].source, equals('trending'));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'handles large video batches without errors',
      setUp: () {
        stubFeed(
          page(
            List.generate(
              100,
              (i) => makeVideo('video-$i', source: 'discovery'),
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RefreshFeedEvent()),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos.length, equals(100));
        expect(state.videos[0].id, equals('video-0'));
        expect(state.videos[99].id, equals('video-99'));
      },
    );
  });

  group('LoadMoreFeedEvent', () {
    final video3 = makeVideo('video-3');
    const nextCursor = HomeFeedCursor(
      hasMoreFollowing: false,
      serverState: {'page': 2},
    );

    blocTest<HomeBloc, HomeState>(
      'appends the next page fetched from the current cursor',
      setUp: () => stubFeed(page([video3], nextCursor: nextCursor)),
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const LoadMoreFeedEvent()),
      expect: () => [
        FeedLoaded(
          videos: sampleVideos,
          nextCursor: seedCursor,
          isLoadingMore: true,
        ),
        FeedLoaded(
          videos: [...sampleVideos, video3],
          offset: 2,
          nextCursor: nextCursor,
        ),
      ],
      verify: (_) {
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: seedCursor,
            limit: 24,
          ),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'filters videos already in the grid',
      setUp: () => stubFeed(page([sampleVideos[1], video3])),
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const LoadMoreFeedEvent()),
      skip: 1,
      expect: () => [
        FeedLoaded(videos: [...sampleVideos, video3], offset: 2),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'clears isLoadingMore after an empty page',
      setUp: () => stubFeed(page([], hasMoreContent: false)),
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const LoadMoreFeedEvent()),
      skip: 1,
      expect: () => [
        FeedLoaded(videos: sampleVideos, offset: 2, hasMoreContent: false),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'clears isLoadingMore after an all-duplicate page',
      setUp: () => stubFeed(page(sampleVideos)),
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const LoadMoreFeedEvent()),
      skip: 1,
      expect: () => [FeedLoaded(videos: sampleVideos, offset: 2)],
    );

    final ignoredSeeds = <String, HomeState Function()>{
      'HomeInitial': () => const HomeInitial(),
      'FeedLoading': () => const FeedLoading(),
      'FeedError': () => const FeedError(),
      'no more content': () =>
          FeedLoaded(videos: sampleVideos, hasMoreContent: false),
      'already loading more': () =>
          FeedLoaded(videos: sampleVideos, isLoadingMore: true),
    };

    for (final entry in ignoredSeeds.entries) {
      blocTest<HomeBloc, HomeState>(
        'is ignored when seeded with ${entry.key}',
        build: buildBloc,
        seed: entry.value,
        act: (bloc) => bloc.add(const LoadMoreFeedEvent()),
        expect: () => <HomeState>[],
        verify: (_) {
          verifyNever(
            () => mockHomeFeedService.getHomeFeedContinuation(
              cursor: any(named: 'cursor'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );
    }

    blocTest<HomeBloc, HomeState>(
      'ignores a duplicate LoadMoreFeedEvent while a page is in flight',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        final pageCompleter = Completer<Map<String, dynamic>>();
        stubFeedFuture(seedCursor, () => pageCompleter.future);

        bloc
          ..add(const LoadMoreFeedEvent())
          ..add(const LoadMoreFeedEvent());
        await untilCalled(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: seedCursor,
            limit: 24,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        pageCompleter.complete(page([video3]));
      },
      expect: () => [
        FeedLoaded(
          videos: sampleVideos,
          nextCursor: seedCursor,
          isLoadingMore: true,
        ),
        FeedLoaded(videos: [...sampleVideos, video3], offset: 2),
      ],
      verify: (_) {
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: seedCursor,
            limit: 24,
          ),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits FeedError on failure and recovers on refresh',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: seedCursor,
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('Network error'));
        stubFeed(page(sampleVideos), cursor: const HomeFeedCursor.initial());

        bloc.add(const LoadMoreFeedEvent());
        await bloc.stream.firstWhere((state) => state is FeedError);
        bloc.add(const RefreshFeedEvent());
      },
      expect: () => [
        FeedLoaded(
          videos: sampleVideos,
          nextCursor: seedCursor,
          isLoadingMore: true,
        ),
        const FeedError(),
        const FeedLoading(),
        FeedLoaded(videos: sampleVideos),
      ],
    );
  });

  group('refresh during load-more', () {
    const refreshedCursor = HomeFeedCursor(
      hasMoreTrending: false,
      serverState: {'page': 'refreshed'},
    );
    final stalePage = page([makeVideo('stale')]);
    final refreshedVideos = [makeVideo('fresh-1'), makeVideo('fresh-2')];

    late Completer<Map<String, dynamic>> staleCompleter;
    late Completer<Map<String, dynamic>> refreshCompleter;

    FeedLoaded loadingMore() => FeedLoaded(
      videos: sampleVideos,
      nextCursor: seedCursor,
      isLoadingMore: true,
    );
    FeedLoaded refreshed() =>
        FeedLoaded(videos: refreshedVideos, nextCursor: refreshedCursor);

    setUp(() {
      stubFeedFuture(seedCursor, () => staleCompleter.future);
      stubFeedFuture(
        const HomeFeedCursor.initial(),
        () => refreshCompleter.future,
      );
    });

    Future<void> startLoadMoreThenRefresh(HomeBloc bloc) async {
      // Created inside `act` so completeError stays in the bloc's error zone.
      staleCompleter = Completer();
      refreshCompleter = Completer();
      bloc.add(const LoadMoreFeedEvent());
      await untilCalled(
        () => mockHomeFeedService.getHomeFeedContinuation(
          cursor: seedCursor,
          limit: 24,
        ),
      );
      bloc.add(const RefreshFeedEvent());
      await untilCalled(
        () => mockHomeFeedService.getHomeFeedContinuation(
          cursor: const HomeFeedCursor.initial(),
          limit: 24,
        ),
      );
    }

    blocTest<HomeBloc, HomeState>(
      'drops a stale page that completes before the refresh',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        await startLoadMoreThenRefresh(bloc);
        staleCompleter.complete(stalePage);
        await Future<void>.delayed(Duration.zero);
        refreshCompleter.complete(
          page(refreshedVideos, nextCursor: refreshedCursor),
        );
      },
      expect: () => [loadingMore(), const FeedLoading(), refreshed()],
    );

    blocTest<HomeBloc, HomeState>(
      'drops a stale page that completes after the refresh',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        await startLoadMoreThenRefresh(bloc);
        refreshCompleter.complete(
          page(refreshedVideos, nextCursor: refreshedCursor),
        );
        await bloc.stream.firstWhere((state) => state == refreshed());
        staleCompleter.complete(stalePage);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [loadingMore(), const FeedLoading(), refreshed()],
    );

    blocTest<HomeBloc, HomeState>(
      'drops a stale failure that completes before the refresh',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        await startLoadMoreThenRefresh(bloc);
        staleCompleter.completeError(Exception('stale'));
        await Future<void>.delayed(Duration.zero);
        refreshCompleter.complete(
          page(refreshedVideos, nextCursor: refreshedCursor),
        );
      },
      expect: () => [loadingMore(), const FeedLoading(), refreshed()],
    );

    blocTest<HomeBloc, HomeState>(
      'drops a stale failure that completes after the refresh',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        await startLoadMoreThenRefresh(bloc);
        refreshCompleter.complete(
          page(refreshedVideos, nextCursor: refreshedCursor),
        );
        await bloc.stream.firstWhere((state) => state == refreshed());
        staleCompleter.completeError(Exception('stale'));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [loadingMore(), const FeedLoading(), refreshed()],
    );

    blocTest<HomeBloc, HomeState>(
      'loads more from the refreshed cursor after the refresh',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        stubFeed(page([makeVideo('fresh-3')]), cursor: refreshedCursor);

        await startLoadMoreThenRefresh(bloc);
        refreshCompleter.complete(
          page(refreshedVideos, nextCursor: refreshedCursor),
        );
        await bloc.stream.firstWhere((state) => state == refreshed());

        bloc.add(const LoadMoreFeedEvent());
        await bloc.stream.firstWhere(
          (state) => state is FeedLoaded && state.videos.length == 3,
        );
        staleCompleter.complete(stalePage);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        loadingMore(),
        const FeedLoading(),
        refreshed(),
        FeedLoaded(
          videos: refreshedVideos,
          nextCursor: refreshedCursor,
          isLoadingMore: true,
        ),
        isA<FeedLoaded>()
            .having((state) => state.videos.last.id, 'last id', 'fresh-3')
            .having((state) => state.offset, 'offset', 2),
      ],
      verify: (_) {
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: refreshedCursor,
            limit: 24,
          ),
        ).called(1);
      },
    );
  });

  group('merging the full-screen feed session', () {
    const sessionCursor = HomeFeedCursor(
      hasMoreFollowing: false,
      serverState: {'pagination': 'keyset'},
    );

    List<String> idsOf(FeedLoaded state) =>
        state.videos.map((video) => video.id).toList();

    blocTest<HomeBloc, HomeState>(
      'adds videos loaded in the full-screen feed to the grid',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        MergeVideoFeedSessionEvent(
          videos: [...sampleVideos, makeVideo('video-3')],
          nextCursor: sessionCursor,
          hasMoreContent: false,
        ),
      ),
      expect: () => [
        isA<FeedLoaded>()
            .having(idsOf, 'video ids', ['video-1', 'video-2', 'video-3'])
            .having((state) => state.offset, 'offset', 2)
            .having((state) => state.nextCursor, 'nextCursor', sessionCursor)
            .having((state) => state.hasMoreContent, 'hasMoreContent', false),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'continues paging from the merged session cursor',
      setUp: () => stubFeed(page([])),
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        bloc.add(
          MergeVideoFeedSessionEvent(
            videos: [...sampleVideos, makeVideo('video-3')],
            nextCursor: sessionCursor,
            hasMoreContent: true,
          ),
        );
        await bloc.stream.firstWhere(
          (state) => state is FeedLoaded && state.videos.length == 3,
        );
        bloc.add(const LoadMoreFeedEvent());
      },
      verify: (_) {
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            cursor: sessionCursor,
            limit: 24,
          ),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'ignores a session that does not continue the grid list',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        MergeVideoFeedSessionEvent(
          videos: [makeVideo('other'), sampleVideos[1], makeVideo('video-3')],
          nextCursor: sessionCursor,
          hasMoreContent: false,
        ),
      ),
      expect: () => <HomeState>[],
    );

    blocTest<HomeBloc, HomeState>(
      'ignores a session while the next page is loading',
      build: buildBloc,
      seed: () => FeedLoaded(videos: sampleVideos, isLoadingMore: true),
      act: (bloc) => bloc.add(
        MergeVideoFeedSessionEvent(
          videos: [...sampleVideos, makeVideo('video-3')],
          nextCursor: sessionCursor,
          hasMoreContent: false,
        ),
      ),
      expect: () => <HomeState>[],
    );

    blocTest<HomeBloc, HomeState>(
      'ignores a session no longer than the grid',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(
        MergeVideoFeedSessionEvent(
          videos: sampleVideos,
          nextCursor: sessionCursor,
          hasMoreContent: false,
        ),
      ),
      expect: () => <HomeState>[],
    );

    final unloadedSeeds = <String, HomeState Function()>{
      'HomeInitial': () => const HomeInitial(),
      'FeedLoading': () => const FeedLoading(),
      'FeedError': () => const FeedError(),
    };

    for (final entry in unloadedSeeds.entries) {
      blocTest<HomeBloc, HomeState>(
        'ignores a session when seeded with ${entry.key}',
        build: buildBloc,
        seed: entry.value,
        act: (bloc) => bloc.add(
          MergeVideoFeedSessionEvent(
            videos: [...sampleVideos, makeVideo('video-3')],
            nextCursor: sessionCursor,
            hasMoreContent: false,
          ),
        ),
        expect: () => <HomeState>[],
      );
    }
  });
}
