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
  late MockHomeFeedService mockHomeFeedService;
  late MockPreferencesService mockPreferencesService;
  late MockSupabaseService mockSupabaseService;
  late MockAuthService mockAuthService;
  late HomeBloc homeBloc;
  late GetIt getIt;

  // Sample test data
  final sampleVideos = [
    {
      'id': 'video-1',
      'title': 'Test Video 1',
      'thumbnail_url': 'https://example.com/thumb1.jpg',
      'username': 'user1',
      'view_count': 100,
      'average_rating': 4.5,
      'source': 'personalized',
    },
    {
      'id': 'video-2',
      'title': 'Test Video 2',
      'thumbnail_url': 'https://example.com/thumb2.jpg',
      'username': 'user2',
      'view_count': 50,
      'average_rating': 4.0,
      'source': 'trending',
    },
  ];

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
  });

  tearDown(() {
    homeBloc.close();
    getIt.reset();
  });

  group('HomeBloc', () {
    /// Test 1: Initial state
    test('initial state is HomeInitial', () {
      expect(homeBloc.state, isA<HomeInitial>());
    });

    /// Test 2: FetchFeedEvent with successful data
    blocTest<HomeBloc, HomeState>(
      'emits [FeedLoading, FeedLoaded] when FetchFeedEvent succeeds',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => sampleVideos);
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>()
            .having((state) => state.videos, 'videos', equals(sampleVideos)),
      ],
    );

    /// Test 3: FetchFeedEvent with empty feed
    blocTest<HomeBloc, HomeState>(
      'emits [FeedLoading, FeedLoaded] with empty videos',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => []);
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>()
            .having((state) => state.videos, 'videos', isEmpty),
      ],
    );

    /// Test 4: FetchFeedEvent with error
    blocTest<HomeBloc, HomeState>(
      'emits [FeedLoading, FeedError] when getHomeFeed throws',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenThrow(Exception('Network error'));
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedError>(),
      ],
    );

    /// Test 5: RefreshFeedEvent uses forceRefresh
    blocTest<HomeBloc, HomeState>(
      'uses forceRefresh when RefreshFeedEvent is triggered',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => sampleVideos);
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const RefreshFeedEvent()),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>(),
      ],
    );

    /// Test 6: Video data integrity - source field preserved
    blocTest<HomeBloc, HomeState>(
      'preserves source field in video data',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => sampleVideos);
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos[0]['source'], equals('personalized'));
        expect(state.videos[1]['source'], equals('trending'));
      },
    );

    /// Test 7: Video data integrity - username preserved
    blocTest<HomeBloc, HomeState>(
      'preserves username field in video data',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => sampleVideos);
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 0)),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos[0]['username'], equals('user1'));
        expect(state.videos[0]['id'], equals('video-1'));
      },
    );

    /// Test 8: Multiple FetchFeedEvents handled
    blocTest<HomeBloc, HomeState>(
      'handles multiple FetchFeedEvents sequentially',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => sampleVideos);
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

    /// Test 9: Service layer is called with correct parameters
    blocTest<HomeBloc, HomeState>(
      'calls getHomeFeed with correct parameters',
      setUp: () {
        when(() => mockHomeFeedService.getHomeFeed(
          limit: 50,
          offset: 25,
          forceRefresh: false,
        )).thenAnswer((_) async => sampleVideos);
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 50, offset: 25)),
      verify: (bloc) {
        verify(() => mockHomeFeedService.getHomeFeed(
          limit: 50,
          offset: 25,
          forceRefresh: false,
        )).called(greaterThan(0));
      },
    );

    /// Test 10: Large batch of videos handled correctly
    blocTest<HomeBloc, HomeState>(
      'handles large video batches without errors',
      setUp: () {
        final largeBatch = List.generate(
          100,
          (i) => {
            'id': 'video-$i',
            'title': 'Test Video $i',
            'thumbnail_url': 'https://example.com/thumb$i.jpg',
            'username': 'user$i',
            'view_count': 100 * i,
            'average_rating': 4.0,
            'source': 'discovery',
          },
        );
        when(() => mockHomeFeedService.getHomeFeed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => largeBatch);
      },
      build: () => homeBloc,
      act: (bloc) => bloc.add(const FetchFeedEvent(limit: 100, offset: 0)),
      verify: (bloc) {
        final state = bloc.state as FeedLoaded;
        expect(state.videos.length, equals(100));
        expect(state.videos[0]['id'], equals('video-0'));
        expect(state.videos[99]['id'], equals('video-99'));
      },
    );
  });
}
