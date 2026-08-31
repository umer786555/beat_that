import 'dart:async';

import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
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
    registerFallbackValue(<String>{});
    registerFallbackValue(const HomeFeedCursor.initial());
  });

  late MockHomeFeedService mockHomeFeedService;
  late MockPreferencesService mockPreferencesService;
  late MockSupabaseService mockSupabaseService;
  late MockAuthService mockAuthService;
  late HomeBloc homeBloc;
  late GetIt getIt;

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

  late List<SportVideo> sampleVideos;

  setUp(() {
    mockHomeFeedService = MockHomeFeedService();
    mockPreferencesService = MockPreferencesService();
    mockSupabaseService = MockSupabaseService();
    mockAuthService = MockAuthService();

    // Setup GetIt with mocked services
    getIt = GetIt.instance;
    getIt.registerSingleton<HomeFeedService>(mockHomeFeedService);
    getIt.registerSingleton<PreferencesService>(mockPreferencesService);
    getIt.registerSingleton<SupabaseService>(mockSupabaseService);
    getIt.registerSingleton<AuthService>(mockAuthService);

    homeBloc = HomeBloc();
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
  });

  tearDown(() {
    homeBloc.close();
    getIt.reset();
  });

  group('HomeBloc', () {
    test('initial state is HomeInitial', () {
      expect(homeBloc.state, isA<HomeInitial>());
    });

    blocTest<HomeBloc, HomeState>(
      'emits [FeedLoading, FeedLoaded] when FetchFeedEvent succeeds',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'videos': sampleVideos,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 1,
              followingOffset: 0,
              trendingOffset: 1,
            ),
            'hasMoreContent': true,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>().having(
          (state) => state.videos,
          'videos',
          equals(sampleVideos),
        ),
      ],
      verify: (_) {
        final captured = verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: captureAny(named: 'seenVideoIds'),
            cursor: captureAny(named: 'cursor'),
            limit: 50,
          ),
        ).captured;
        expect(captured[0] as Set<String>, isEmpty);
        expect(captured[1], equals(const HomeFeedCursor.initial()));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits [FeedLoading, FeedLoaded] with empty videos',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'videos': <SportVideo>[],
            'nextCursor': const HomeFeedCursor.initial(),
            'hasMoreContent': false,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>().having((state) => state.videos, 'videos', isEmpty),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits [FeedLoading, FeedError] when continuation fetch throws',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('Network error'));
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      expect: () => [isA<FeedLoading>(), isA<FeedError>()],
    );

    blocTest<HomeBloc, HomeState>(
      'reloads feed when RefreshFeedEvent is triggered',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'videos': sampleVideos,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 1,
              followingOffset: 0,
              trendingOffset: 1,
            ),
            'hasMoreContent': true,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const RefreshFeedEvent()),
      expect: () => [isA<FeedLoading>(), isA<FeedLoaded>()],
      verify: (_) {
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: const HomeFeedCursor.initial(),
            limit: 24,
          ),
        ).called(1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'preserves source field in video data',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'videos': sampleVideos,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 1,
              followingOffset: 0,
              trendingOffset: 1,
            ),
            'hasMoreContent': true,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos[0].source, equals('personalized'));
        expect(state.videos[1].source, equals('trending'));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'preserves username field in video data',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'videos': sampleVideos,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 1,
              followingOffset: 0,
              trendingOffset: 1,
            ),
            'hasMoreContent': true,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos[0].username, equals('user1'));
        expect(state.videos[0].id, equals('video-1'));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'handles multiple FetchFeedEvents sequentially',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (invocation) async => {
            'videos': sampleVideos,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 1,
              followingOffset: 0,
              trendingOffset: 1,
            ),
            'hasMoreContent': true,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) {
        bloc.add(const FetchFeedEvent(limit: 50, offset: 0));
        bloc.add(const FetchFeedEvent(limit: 50, offset: 50));
      },
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>(),
        isA<FeedLoading>(),
        isA<FeedLoaded>(),
      ],
    );

    test(
      'ignores duplicate LoadMoreFeedEvent while pagination is in flight',
      () async {
        final paginationCompleter = Completer<Map<String, dynamic>>();

        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: const HomeFeedCursor.initial(),
            limit: 2,
          ),
        ).thenAnswer(
          (_) async => {
            'videos': sampleVideos,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 1,
              followingOffset: 0,
              trendingOffset: 1,
            ),
            'hasMoreContent': true,
          },
        );

        const nextCursor = HomeFeedCursor(
          personalizedOffset: 1,
          followingOffset: 0,
          trendingOffset: 1,
        );
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: nextCursor,
            limit: 24,
          ),
        ).thenAnswer((_) => paginationCompleter.future);

        homeBloc.add(const FetchFeedEvent(limit: 2, offset: 0));
        await homeBloc.stream.firstWhere((state) => state is FeedLoaded);

        homeBloc.add(const LoadMoreFeedEvent());
        homeBloc.add(const LoadMoreFeedEvent());

        await untilCalled(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: nextCursor,
            limit: 24,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final capturedSeenVideoIds = verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: captureAny(named: 'seenVideoIds'),
            cursor: nextCursor,
            limit: 24,
          ),
        );
        expect(capturedSeenVideoIds.callCount, equals(1));
        final seenVideoIds =
            capturedSeenVideoIds.captured.single as Set<String>;
        expect(seenVideoIds, equals({'video-1', 'video-2'}));

        paginationCompleter.complete({
          'videos': [
            makeVideo(
              'video-3',
              userId: 'user-3',
              title: 'Test Video 3',
              username: 'user3',
              source: 'following',
            ),
          ],
          'nextCursor': const HomeFeedCursor(
            personalizedOffset: 1,
            followingOffset: 1,
            trendingOffset: 1,
          ),
          'hasMoreContent': true,
        });
        await homeBloc.stream.firstWhere(
          (state) => state is FeedLoaded && state.offset == 2,
        );
      },
    );

    blocTest<HomeBloc, HomeState>(
      'calls continuation with correct parameters',
      setUp: () {
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: 50,
          ),
        ).thenAnswer(
          (_) async => {
            'videos': sampleVideos,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 25,
              followingOffset: 25,
              trendingOffset: 25,
            ),
            'hasMoreContent': true,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 25)),
      verify: (bloc) {
        verify(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: const HomeFeedCursor.initial(),
            limit: 50,
          ),
        ).called(greaterThan(0));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'handles large video batches without errors',
      setUp: () {
        final largeBatch = List.generate(
          100,
          (i) => makeVideo(
            'video-$i',
            userId: 'user-$i',
            title: 'Test Video $i',
            username: 'user$i',
            source: 'discovery',
            viewCount: 100 * i,
          ),
        );
        when(
          () => mockHomeFeedService.getHomeFeedContinuation(
            seenVideoIds: any(named: 'seenVideoIds'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'videos': largeBatch,
            'nextCursor': const HomeFeedCursor(
              personalizedOffset: 34,
              followingOffset: 33,
              trendingOffset: 33,
            ),
            'hasMoreContent': true,
          },
        );
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 100, offset: 0)),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos.length, equals(100));
        expect(state.videos[0].id, equals('video-0'));
        expect(state.videos[99].id, equals('video-99'));
      },
    );
  });
}
