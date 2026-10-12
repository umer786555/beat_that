import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/supabase_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const HomeFeedCursor.initial());
  });

  late MockSupabaseService mockSupabaseService;
  late HomeFeedService homeFeedService;
  final getIt = GetIt.instance;

  SportVideo makeVideo(
    String id, {
    String sourceUser = 'user-1',
    String title = 'Video',
    double bayesianScore = 0,
    String? username,
  }) {
    return SportVideo(
      id: id,
      userId: sourceUser,
      userVideoId: id,
      title: title,
      description: '',
      videoPath: '$id.mp4',
      thumbnailPath: '$id.jpg',
      thumbnailUrl: 'https://example.com/$id.jpg',
      username: username ?? sourceUser,
      bayesianScore: bayesianScore,
    );
  }

  late SportVideo videoFromPersonalized;
  late SportVideo videoFromTrending;

  setUp(() {
    // Clear GetIt and register mocks
    if (getIt.isRegistered<SupabaseService>()) {
      getIt.unregister<SupabaseService>();
    }

    mockSupabaseService = MockSupabaseService();
    getIt.registerSingleton<SupabaseService>(mockSupabaseService);

    // Create service (will use mocked SupabaseService from GetIt)
    homeFeedService = HomeFeedService();
    videoFromPersonalized = makeVideo(
      'p-1',
      sourceUser: 'user-1',
      title: 'Personalized Video',
      bayesianScore: 80,
      username: 'user1',
    );
    videoFromTrending = makeVideo(
      't-1',
      sourceUser: 'user-3',
      title: 'Trending Video',
      bayesianScore: 90,
      username: 'user3',
    );
  });

  tearDown(() {
    getIt.reset();
  });

  group('HomeFeedService RPC continuation', () {
    test(
      'delegates continuation fetches to the RPC-backed Supabase call',
      () async {
        final nextCursor = HomeFeedCursor.fromMap({
          'pagination': 'keyset',
          'hasMorePersonalized': true,
          'hasMoreFollowing': false,
          'hasMoreTrending': true,
          'hasMoreDiscovery': true,
        });

        when(
          () => mockSupabaseService.getHomeFeedPage(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => {
            'videos': [videoFromPersonalized, videoFromTrending],
            'nextCursor': nextCursor,
            'hasMoreContent': true,
          },
        );

        final result = await homeFeedService.getHomeFeedContinuation(
          cursor: const HomeFeedCursor.initial(),
          limit: 24,
        );

        expect(
          (result['videos'] as List<SportVideo>).map((video) => video.id),
          ['p-1', 't-1'],
        );
        expect(result['nextCursor'], equals(nextCursor));
        expect(result['hasMoreContent'], isTrue);

        verify(
          () => mockSupabaseService.getHomeFeedPage(
            cursor: const HomeFeedCursor.initial(),
            limit: 24,
          ),
        ).called(1);
      },
    );

    test('propagates RPC failures to the caller', () async {
      when(
        () => mockSupabaseService.getHomeFeedPage(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(Exception('RPC unavailable'));

      await expectLater(
        homeFeedService.getHomeFeedContinuation(
          cursor: const HomeFeedCursor.initial(),
          limit: 24,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
