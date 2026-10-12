import 'dart:async';

import 'package:beat_that/screens/explore/bloc/explore_bloc.dart';
import 'package:beat_that/services/explore_feed_progress_store.dart';
import 'package:beat_that/models/explore_filter_source_row.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabaseService;

  setUp(() {
    mockSupabaseService = MockSupabaseService();
    locator.registerSingleton<SupabaseService>(mockSupabaseService);
  });

  tearDown(() async {
    await locator.reset();
  });

  blocTest<ExploreBloc, ExploreState>(
    'loads explore filters into bloc state',
    setUp: () {
      when(() => mockSupabaseService.getExploreFilters()).thenAnswer(
        (_) async => const [
          ExploreFilterSourceRow(
            name: 'basketball',
            displayName: 'Basketball',
            kind: 'sport',
          ),
          ExploreFilterSourceRow(
            name: 'valorant',
            displayName: 'Valorant',
            kind: 'game',
          ),
        ],
      );
    },
    build: () => ExploreBloc(),
    act: (bloc) => bloc.add(const LoadExploreFiltersEvent()),
    expect: () => [
      isA<ExploreInitial>()
          .having((state) => state.filterCatalog.sports.length, 'sports', 1)
          .having((state) => state.filterCatalog.games.length, 'games', 1)
          .having(
            (state) => state.filterCatalog.games.first.id,
            'game filter id',
            'valorant',
          ),
    ],
  );

  blocTest<ExploreBloc, ExploreState>(
    'loads random explore videos when there is no query or sport filter',
    setUp: () {
      when(
        () => mockSupabaseService.getRandomExploreVideos(
          limit: 20,
          seed: any(named: 'seed'),
          afterId: null,
          hasWrapped: false,
        ),
      ).thenAnswer(
        (_) async => {
          'videos': [
            SportVideo(
              id: 'video-1',
              userId: 'user-1',
              title: 'Baseline drill',
              description: '',
              videoPath: 'profiles/user-1/videos/video1.mp4',
              thumbnailPath: 'profiles/user-1/thumbnails/thumb1.jpg',
              thumbnailUrl: 'https://example.com/thumb1.jpg',
              username: 'coach1',
            ),
          ],
          'hasMore': true,
          'nextCursor': {'afterId': 'video-1', 'hasWrapped': false},
          'seed': 'seed-1',
        },
      );
    },
    build: () => ExploreBloc(),
    act: (bloc) => bloc.add(const SearchExploreVideosEvent(query: '')),
    expect: () => [
      isA<ExploreLoading>()
          .having((state) => state.query, 'query', '')
          .having((state) => state.selectedFilterId, 'selectedFilterId', null),
      isA<ExploreLoaded>()
          .having((state) => state.isRandomFeed, 'isRandomFeed', true)
          .having((state) => state.videos.length, 'videos length', 1)
          .having((state) => state.randomSeed, 'randomSeed', 'seed-1')
          .having((state) => state.randomAfterId, 'randomAfterId', 'video-1'),
    ],
  );

  blocTest<ExploreBloc, ExploreState>(
    'emits an error when the random explore RPC fails',
    setUp: () {
      when(
        () => mockSupabaseService.getRandomExploreVideos(
          limit: 20,
          seed: any(named: 'seed'),
          afterId: null,
          hasWrapped: false,
        ),
      ).thenAnswer(
        (_) async => {
          'videos': const <SportVideo>[],
          'hasMore': false,
          'nextCursor': null,
          'seed': null,
          'error': 'rpc failed',
        },
      );
    },
    build: () => ExploreBloc(),
    act: (bloc) => bloc.add(const SearchExploreVideosEvent(query: '')),
    expect: () => [
      isA<ExploreLoading>()
          .having((state) => state.query, 'query', '')
          .having((state) => state.selectedFilterId, 'selectedFilterId', null),
      isA<ExploreError>()
          .having(
            (state) => state.message,
            'message',
            'Failed to search videos: Exception: rpc failed',
          )
          .having((state) => state.query, 'query', ''),
    ],
  );

  blocTest<ExploreBloc, ExploreState>(
    'refreshes the current loaded search from bloc state',
    setUp: () {
      when(
        () => mockSupabaseService.searchVideosByTitle(
          '',
          limit: 20,
          offset: 0,
          sportId: 'tennis',
        ),
      ).thenAnswer(
        (_) async => {
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
            ),
          ],
          'totalCount': 1,
          'hasMore': false,
          'nextOffset': 1,
        },
      );
    },
    build: () => ExploreBloc(),
    seed: () => const ExploreLoaded(
      query: '',
      selectedFilterId: 'tennis',
      videos: [],
      totalCount: 0,
      hasMore: false,
      nextOffset: 0,
    ),
    act: (bloc) => bloc.add(const RefreshExploreVideosEvent()),
    expect: () => [
      isA<ExploreLoading>()
          .having((state) => state.query, 'query', '')
          .having(
            (state) => state.selectedFilterId,
            'selectedFilterId',
            'tennis',
          ),
      isA<ExploreLoaded>()
          .having(
            (state) => state.selectedFilterId,
            'selectedFilterId',
            'tennis',
          )
          .having((state) => state.videos.length, 'videos length', 1),
    ],
    verify: (_) {
      verify(
        () => mockSupabaseService.searchVideosByTitle(
          '',
          limit: 20,
          offset: 0,
          sportId: 'tennis',
        ),
      ).called(1);
    },
  );

  group('stale responses', () {
    late Completer<Map<String, dynamic>> slowResponse;

    SportVideo video(String id) => SportVideo(
      id: id,
      userId: 'user-1',
      title: id,
      description: '',
      videoPath: '$id.mp4',
      thumbnailPath: '$id.jpg',
    );

    Map<String, dynamic> searchResult(String id) => {
      'videos': [video(id)],
      'totalCount': 1,
      'hasMore': false,
      'nextOffset': 1,
    };

    List<String> idsOf(ExploreLoaded state) =>
        state.videos.map((video) => video.id).toList();

    setUp(() {
      slowResponse = Completer<Map<String, dynamic>>();
      when(
        () => mockSupabaseService.searchVideosByTitle(
          'boxing',
          limit: 20,
          offset: 0,
          sportId: null,
        ),
      ).thenAnswer((_) async => searchResult('boxing-1'));
    });

    blocTest<ExploreBloc, ExploreState>(
      'ignores an older search that finishes after a newer one',
      setUp: () {
        when(
          () => mockSupabaseService.searchVideosByTitle(
            'box',
            limit: 20,
            offset: 0,
            sportId: null,
          ),
        ).thenAnswer((_) => slowResponse.future);
      },
      build: () => ExploreBloc(),
      act: (bloc) async {
        bloc.add(const SearchExploreVideosEvent(query: 'box'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SearchExploreVideosEvent(query: 'boxing'));
        await Future<void>.delayed(Duration.zero);
        slowResponse.complete(searchResult('box-1'));
      },
      expect: () => [
        isA<ExploreLoading>().having((state) => state.query, 'query', 'box'),
        isA<ExploreLoading>().having((state) => state.query, 'query', 'boxing'),
        isA<ExploreLoaded>()
            .having((state) => state.query, 'query', 'boxing')
            .having(idsOf, 'video ids', ['boxing-1']),
      ],
    );

    blocTest<ExploreBloc, ExploreState>(
      'ignores a load-more from the previous search',
      setUp: () {
        when(
          () => mockSupabaseService.searchVideosByTitle(
            'box',
            limit: 20,
            offset: 1,
            sportId: null,
          ),
        ).thenAnswer((_) => slowResponse.future);
      },
      build: () => ExploreBloc(),
      seed: () => ExploreLoaded(
        query: 'box',
        videos: [video('box-1')],
        totalCount: 2,
        hasMore: true,
        nextOffset: 1,
      ),
      act: (bloc) async {
        bloc.add(const LoadMoreExploreVideosEvent());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SearchExploreVideosEvent(query: 'boxing'));
        await Future<void>.delayed(Duration.zero);
        slowResponse.complete(searchResult('box-2'));
      },
      expect: () => [
        isA<ExploreLoaded>().having(
          (state) => state.isLoadingMore,
          'isLoadingMore',
          true,
        ),
        isA<ExploreLoading>().having((state) => state.query, 'query', 'boxing'),
        isA<ExploreLoaded>()
            .having((state) => state.query, 'query', 'boxing')
            .having(idsOf, 'video ids', ['boxing-1']),
      ],
    );
  });

  group('browse seed', () {
    SportVideo video(String id) => SportVideo(
      id: id,
      userId: 'user-1',
      title: id,
      description: '',
      videoPath: '$id.mp4',
      thumbnailPath: '$id.jpg',
    );

    ExploreLoaded browseState() => ExploreLoaded(
      query: '',
      videos: [video('video-1'), video('video-2')],
      totalCount: 2,
      hasMore: true,
      nextOffset: 0,
      isRandomFeed: true,
      randomSeed: 'session-seed',
      randomAfterId: 'video-2',
    );

    ExploreFeedProgress feedProgress({
      String? seed = 'session-seed',
      List<String> ids = const ['video-1', 'video-2', 'video-3'],
    }) => ExploreFeedProgress(
      query: '',
      selectedSportId: null,
      isRandomFeed: true,
      videos: ids.map(video).toList(),
      currentIndex: ids.length - 1,
      nextOffset: 0,
      hasMore: false,
      randomSeed: seed,
      randomAfterId: ids.last,
    );

    blocTest<ExploreBloc, ExploreState>(
      'adds pages loaded in the full-screen feed to the grid',
      build: () => ExploreBloc(),
      seed: browseState,
      act: (bloc) => bloc.add(MergeExploreFeedProgressEvent(feedProgress())),
      expect: () => [
        isA<ExploreLoaded>()
            .having(
              (state) => state.videos.map((video) => video.id).toList(),
              'video ids',
              ['video-1', 'video-2', 'video-3'],
            )
            .having((state) => state.randomAfterId, 'randomAfterId', 'video-3')
            .having((state) => state.hasMore, 'hasMore', false),
      ],
    );

    blocTest<ExploreBloc, ExploreState>(
      'ignores feed progress from a different browse session',
      build: () => ExploreBloc(),
      seed: browseState,
      act: (bloc) => bloc.add(
        MergeExploreFeedProgressEvent(feedProgress(seed: 'other-seed')),
      ),
      expect: () => <ExploreState>[],
    );

    blocTest<ExploreBloc, ExploreState>(
      'ignores feed progress that does not continue the grid list',
      build: () => ExploreBloc(),
      seed: browseState,
      act: (bloc) => bloc.add(
        MergeExploreFeedProgressEvent(
          feedProgress(ids: const ['video-9', 'video-2', 'video-3']),
        ),
      ),
      expect: () => <ExploreState>[],
    );

    blocTest<ExploreBloc, ExploreState>(
      'queries shorter than 3 characters browse instead of searching',
      setUp: () {
        when(
          () => mockSupabaseService.getRandomExploreVideos(
            limit: 20,
            seed: any(named: 'seed'),
            afterId: null,
            hasWrapped: false,
          ),
        ).thenAnswer(
          (_) async => {
            'videos': [video('video-1')],
            'hasMore': false,
            'nextCursor': null,
            'seed': 'seed-1',
          },
        );
      },
      build: () => ExploreBloc(),
      act: (bloc) => bloc.add(const SearchExploreVideosEvent(query: ' ab ')),
      expect: () => [
        isA<ExploreLoading>().having((state) => state.query, 'query', ''),
        isA<ExploreLoaded>()
            .having((state) => state.isRandomFeed, 'isRandomFeed', true)
            .having((state) => state.query, 'query', ''),
      ],
      verify: (_) {
        verifyNever(
          () => mockSupabaseService.searchVideosByTitle(
            any(),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sportId: any(named: 'sportId'),
          ),
        );
      },
    );

    blocTest<ExploreBloc, ExploreState>(
      'each browse load or refresh uses a new random seed',
      setUp: () {
        when(
          () => mockSupabaseService.getRandomExploreVideos(
            limit: 20,
            seed: any(named: 'seed'),
            afterId: null,
            hasWrapped: false,
          ),
        ).thenAnswer(
          (invocation) async => {
            'videos': const <SportVideo>[],
            'hasMore': false,
            'nextCursor': null,
            'seed': invocation.namedArguments[#seed],
          },
        );
      },
      build: () => ExploreBloc(),
      act: (bloc) async {
        bloc.add(const SearchExploreVideosEvent(query: ''));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SearchExploreVideosEvent(query: ''));
      },
      verify: (_) {
        final seeds = verify(
          () => mockSupabaseService.getRandomExploreVideos(
            limit: 20,
            seed: captureAny(named: 'seed'),
            afterId: null,
            hasWrapped: false,
          ),
        ).captured;

        expect(seeds, hasLength(2));
        expect(seeds, everyElement(isA<String>()));
        expect(seeds.first, isNot(equals(seeds.last)));
      },
    );

    blocTest<ExploreBloc, ExploreState>(
      'load more continues the same seed and cursor',
      setUp: () {
        when(
          () => mockSupabaseService.getRandomExploreVideos(
            limit: 20,
            seed: 'session-seed',
            afterId: 'video-1',
            hasWrapped: false,
          ),
        ).thenAnswer(
          (_) async => {
            'videos': [video('video-2')],
            'hasMore': false,
            'nextCursor': null,
            'seed': 'session-seed',
          },
        );
      },
      build: () => ExploreBloc(),
      seed: () => ExploreLoaded(
        query: '',
        videos: [video('video-1')],
        totalCount: 1,
        hasMore: true,
        nextOffset: 0,
        isRandomFeed: true,
        randomSeed: 'session-seed',
        randomAfterId: 'video-1',
      ),
      act: (bloc) => bloc.add(const LoadMoreExploreVideosEvent()),
      expect: () => [
        isA<ExploreLoaded>().having(
          (state) => state.isLoadingMore,
          'isLoadingMore',
          true,
        ),
        isA<ExploreLoaded>()
            .having(
              (state) => state.videos.map((video) => video.id).toList(),
              'video ids',
              ['video-1', 'video-2'],
            )
            .having((state) => state.randomSeed, 'randomSeed', 'session-seed')
            .having((state) => state.hasMore, 'hasMore', false),
      ],
    );

    blocTest<ExploreBloc, ExploreState>(
      'after a failed load more, scrolling waits for an explicit retry',
      setUp: () {
        var calls = 0;
        when(
          () => mockSupabaseService.getRandomExploreVideos(
            limit: 20,
            seed: 'session-seed',
            afterId: 'video-1',
            hasWrapped: false,
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return {
              'videos': const <SportVideo>[],
              'hasMore': false,
              'nextCursor': null,
              'seed': 'session-seed',
              'error': 'offline',
            };
          }
          return {
            'videos': [video('video-2')],
            'hasMore': true,
            'nextCursor': {'afterId': 'video-2', 'hasWrapped': false},
            'seed': 'session-seed',
          };
        });
      },
      build: () => ExploreBloc(),
      seed: () => ExploreLoaded(
        query: '',
        videos: [video('video-1')],
        totalCount: 1,
        hasMore: true,
        nextOffset: 0,
        isRandomFeed: true,
        randomSeed: 'session-seed',
        randomAfterId: 'video-1',
      ),
      act: (bloc) async {
        bloc.add(const LoadMoreExploreVideosEvent());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LoadMoreExploreVideosEvent());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LoadMoreExploreVideosEvent(isRetry: true));
      },
      expect: () => [
        isA<ExploreLoaded>().having(
          (state) => state.isLoadingMore,
          'isLoadingMore',
          true,
        ),
        isA<ExploreLoaded>()
            .having((state) => state.isLoadingMore, 'isLoadingMore', false)
            .having((state) => state.loadMoreFailed, 'loadMoreFailed', true),
        isA<ExploreLoaded>()
            .having((state) => state.isLoadingMore, 'isLoadingMore', true)
            .having((state) => state.loadMoreFailed, 'loadMoreFailed', false),
        isA<ExploreLoaded>()
            .having(
              (state) => state.videos.map((video) => video.id).toList(),
              'video ids',
              ['video-1', 'video-2'],
            )
            .having((state) => state.loadMoreFailed, 'loadMoreFailed', false)
            .having((state) => state.randomAfterId, 'randomAfterId', 'video-2'),
      ],
      verify: (_) {
        verify(
          () => mockSupabaseService.getRandomExploreVideos(
            limit: 20,
            seed: 'session-seed',
            afterId: 'video-1',
            hasWrapped: false,
          ),
        ).called(2);
      },
    );
  });
}
