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
    registerFallbackValue(<String>{});
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
  late SportVideo videoFromFollowing;
  late SportVideo videoFromTrending;
  late SportVideo videoFromDiscovery;

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
    videoFromFollowing = makeVideo(
      'f-1',
      sourceUser: 'user-2',
      title: 'Following Video',
      bayesianScore: 60,
      username: 'user2',
    );
    videoFromTrending = makeVideo(
      't-1',
      sourceUser: 'user-3',
      title: 'Trending Video',
      bayesianScore: 90,
      username: 'user3',
    );
    videoFromDiscovery = makeVideo(
      'd-1',
      sourceUser: 'user-4',
      title: 'Discovery Video',
      bayesianScore: 40,
      username: 'user4',
    );
  });

  tearDown(() {
    getIt.reset();
  });

  group('HomeFeedService', () {
    test('continuation fetches and blends from all 4 sources', () async {
      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [videoFromPersonalized]);

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [videoFromFollowing]);

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [videoFromTrending]);

      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => [videoFromDiscovery]);

      final response = await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 50,
      );
      final result = List<SportVideo>.from(response['videos'] as List<dynamic>);

      expect(result.length, equals(4));
      expect(
        result.map((video) => video.id),
        containsAll(['p-1', 'f-1', 't-1', 'd-1']),
      );
      expect(
        result.firstWhere((video) => video.id == 'p-1').source,
        equals('personalized'),
      );
      expect(
        result.firstWhere((video) => video.id == 'f-1').source,
        equals('following'),
      );
      expect(
        result.firstWhere((video) => video.id == 't-1').source,
        equals('trending'),
      );
      expect(
        result.firstWhere((video) => video.id == 'd-1').source,
        equals('discovery'),
      );

      verify(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).called(1);
      verify(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).called(1);
      verify(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).called(1);
      verify(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).called(1);
    });

    test('continuation deduplicates videos by ID, keeping first occurrence', () async {
      final duplicateInTrending = makeVideo(
        'p-1',
        sourceUser: 'user-5',
        title: 'Trending version of p-1',
        bayesianScore: 95,
        username: 'user5',
      );

      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [videoFromPersonalized]);

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [duplicateInTrending]);

      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => []);

      final response = await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 50,
      );
      final result = List<SportVideo>.from(response['videos'] as List<dynamic>);

      expect(result.length, equals(1));
      expect(result[0].id, equals('p-1'));
      expect(result[0].source, equals('personalized'));
      expect(result[0].bayesianScore, equals(80));
    });

    test('continuation sorts videos by composite score descending', () async {
      final lowScoringVideo = makeVideo(
        'low',
        sourceUser: 'user-low',
        bayesianScore: 20,
        username: 'user_low',
      );
      final highScoringVideo = makeVideo(
        'high',
        sourceUser: 'user-high',
        bayesianScore: 100,
        username: 'user_high',
      );

      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [lowScoringVideo]);

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [highScoringVideo]);

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => []);

      final response = await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 50,
      );
      final result = List<SportVideo>.from(response['videos'] as List<dynamic>);

      expect(result.length, equals(2));
      expect(result[0].id, equals('high'));
      expect(result[1].id, equals('low'));
    });

    test('propagates source fetch errors to the caller', () async {
      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenThrow(Exception('Network error'));

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => []);

      await expectLater(
        homeFeedService.getHomeFeedContinuation(
          seenVideoIds: <String>{},
          cursor: const HomeFeedCursor.initial(),
          limit: 50,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('calls source queries with weighted fetch amounts', () async {
      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => []);

      await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 50,
      );

      verify(() => mockSupabaseService.getPersonalizedVideos(
            limit: 21,
            offset: 0,
          )).called(1);
      verify(() => mockSupabaseService.getFollowingVideos(
            limit: 16,
            offset: 0,
          )).called(1);
      verify(() => mockSupabaseService.getTrendingVideos(
            limit: 11,
            offset: 0,
          )).called(1);
      verify(() => mockSupabaseService.getDiscoveryVideos(
            limit: 6,
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).called(1);
    });

    test('returns empty list when all sources return empty', () async {
      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => []);

      final response = await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 50,
      );
      final result = List<SportVideo>.from(response['videos'] as List<dynamic>);

      expect(result, isEmpty);
      expect(response['hasMoreContent'], isFalse);
    });

    test('returns videos even when some sources are empty', () async {
      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [videoFromPersonalized]);

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []); // Empty

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [videoFromTrending]); // Has data

      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => []);

      final response = await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 50,
      );
      final result = List<SportVideo>.from(response['videos'] as List<dynamic>);

      expect(result.length, equals(2));
      expect(
        result.map((video) => video.id),
        containsAll(['p-1', 't-1']),
      );
    });

    test('continuation advances source offsets independently', () async {
      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);
      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);
      when(() => mockSupabaseService.getTrendingVideos(limit: 6, offset: 0))
          .thenAnswer(
            (_) async => List.generate(
              6,
              (index) => makeVideo(
                't-$index',
                sourceUser: 'trend-$index',
                bayesianScore: 90 - index.toDouble(),
              ),
            ),
          );
      when(() => mockSupabaseService.getTrendingVideos(limit: 6, offset: 6))
          .thenAnswer(
            (_) async => [
              makeVideo('t-6', sourceUser: 'trend-6', bayesianScore: 84),
              makeVideo('t-7', sourceUser: 'trend-7', bayesianScore: 83),
              makeVideo('t-8', sourceUser: 'trend-8', bayesianScore: 82),
            ],
          );

      var discoveryCallCount = 0;
      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((invocation) async {
            discoveryCallCount++;
            final excludedIds = invocation.namedArguments[#excludedVideoIds]
                as Set<String>;

            if (discoveryCallCount == 1) {
              expect(
                excludedIds,
                containsAll(
                  List.generate(6, (index) => 't-$index'),
                ),
              );
              return [
                makeVideo('t-6', sourceUser: 'discover-6'),
                makeVideo('t-7', sourceUser: 'discover-7'),
                makeVideo('t-8', sourceUser: 'discover-8'),
              ];
            }

            expect(excludedIds, containsAll(['t-6', 't-7', 't-8']));
            return [
              makeVideo('old-1', sourceUser: 'old-1'),
              makeVideo('old-2', sourceUser: 'old-2'),
            ];
          });

      final result = await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 24,
      );

      final videos = List<SportVideo>.from(result['videos'] as List<dynamic>);
      final nextCursor = result['nextCursor'] as HomeFeedCursor;

      expect(
        videos.map((video) => video.id),
        containsAll([
          't-0',
          't-1',
          't-2',
          't-3',
          't-4',
          't-5',
          't-6',
          't-7',
          't-8',
          'old-1',
          'old-2',
        ]),
      );
      expect(videos.length, equals(11));
      expect(nextCursor.trendingOffset, equals(9));
      expect(nextCursor.hasMoreTrending, isFalse);
      verifyNever(() => mockSupabaseService.getTrendingVideos(
            limit: 6,
            offset: 9,
          ));
    });

    test('continuation only exhausts after an empty blended batch', () async {
      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);
      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);
      when(() => mockSupabaseService.getDiscoveryVideos(
            limit: any(named: 'limit'),
            excludedVideoIds: any(named: 'excludedVideoIds'),
          )).thenAnswer((_) async => []);
      when(() => mockSupabaseService.getTrendingVideos(limit: 6, offset: 0))
          .thenAnswer(
            (_) async => List.generate(
              6,
              (index) => makeVideo('t-$index', sourceUser: 'trend-$index'),
            ),
          );
      when(() => mockSupabaseService.getTrendingVideos(limit: 6, offset: 6))
          .thenAnswer((_) async => []);

      final result = await homeFeedService.getHomeFeedContinuation(
        seenVideoIds: <String>{},
        cursor: const HomeFeedCursor.initial(),
        limit: 24,
      );

      final videos = List<SportVideo>.from(result['videos'] as List<dynamic>);
      final nextCursor = result['nextCursor'] as HomeFeedCursor;
      expect(videos.length, equals(6));
      expect(nextCursor.trendingOffset, equals(6));
      expect(result['hasMoreContent'], isFalse);
    });
  });
}

