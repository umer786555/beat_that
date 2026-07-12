import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:beat_that/services/home_feed_service.dart';
import 'package:beat_that/services/supabase_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabaseService;
  late HomeFeedService homeFeedService;
  final getIt = GetIt.instance;

  // Reusable test video fixtures
  final videoFromPersonalized = {
    'id': 'p-1',
    'title': 'Personalized Video',
    'bayesian_score': 80.0,
    'username': 'user1',
  };

  final videoFromFollowing = {
    'id': 'f-1',
    'title': 'Following Video',
    'bayesian_score': 60.0,
    'username': 'user2',
  };

  final videoFromTrending = {
    'id': 't-1',
    'title': 'Trending Video',
    'bayesian_score': 90.0,
    'username': 'user3',
  };

  final videoFromDiscovery = {
    'id': 'd-1',
    'title': 'Discovery Video',
    'bayesian_score': 40.0,
    'username': 'user4',
  };

  setUp(() {
    // Clear GetIt and register mocks
    if (getIt.isRegistered<SupabaseService>()) {
      getIt.unregister<SupabaseService>();
    }

    mockSupabaseService = MockSupabaseService();
    getIt.registerSingleton<SupabaseService>(mockSupabaseService);

    // Create service (will use mocked SupabaseService from GetIt)
    homeFeedService = HomeFeedService();
  });

  tearDown(() {
    getIt.reset();
  });

  group('HomeFeedService - Real Service Tests', () {
    /// Test 1: Successfully fetches and blends from all 4 sources
    test('getHomeFeed fetches and blends from all 4 sources', () async {
      // Arrange: Mock all 4 sources
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

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => [videoFromDiscovery]);

      // Act: Get feed
      final result = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: All 4 videos present and blended
      expect(result.length, equals(4));
      expect(result.map((v) => v['id']), containsAll(['p-1', 'f-1', 't-1', 'd-1']));

      // Verify mocks were called
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
      verify(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).called(1);
    });

    /// Test 2: Deduplicates videos with same ID
    test('deduplicates videos by ID, keeping first occurrence', () async {
      // Arrange: Same video ID in personalized and trending
      final duplicateInTrending = {
        'id': 'p-1', // Same ID as personalized
        'title': 'Trending version of p-1',
        'bayesian_score': 95.0,
        'username': 'user5',
      };

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

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []);

      // Act
      final result = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: Only personalized version kept
      expect(result.length, equals(1));
      expect(result[0]['id'], equals('p-1'));
      expect(result[0]['source'], equals('personalized')); // Original source
      expect(result[0]['bayesian_score'], equals(80.0)); // Original score
    });

    /// Test 3: Sorts videos by composite score (descending)
    test('sorts videos by composite score descending', () async {
      final lowScoringVideo = {
        'id': 'low',
        'bayesian_score': 20.0, // Will have lowest composite score
        'username': 'user_low',
      };

      final highScoringVideo = {
        'id': 'high',
        'bayesian_score': 100.0, // Will have highest composite score
        'username': 'user_high',
      };

      when(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [lowScoringVideo]); // 0.40 + (0.20 * 0.2) = 0.44

      when(() => mockSupabaseService.getFollowingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [highScoringVideo]); // 0.30 + (1.0 * 0.2) = 0.50

      when(() => mockSupabaseService.getTrendingVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []);

      // Act
      final result = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: High scoring video is first (even though it's from "following")
      expect(result.length, equals(2));
      expect(result[0]['id'], equals('high')); // Higher composite score comes first
      expect(result[1]['id'], equals('low'));
    });

    /// Test 4: Uses cache on subsequent calls
    test('caches feed by offset and returns from cache on subsequent calls', () async {
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
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []);

      // Act: First call
      final result1 = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Verify all 4 methods called once
      expect(result1.length, equals(1));

      // Act: Second call (should use cache)
      final result2 = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: Same result, but mocks called only once (not twice)
      expect(result2, equals(result1));
      verify(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).called(1); // Called only once, not twice
    });

    /// Test 5: Bypasses cache with forceRefresh=true
    test('bypasses cache when forceRefresh=true', () async {
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
          )).thenAnswer((_) async => []);

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []);

      // Act: First call
      await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Act: Force refresh
      await homeFeedService.getHomeFeed(limit: 50, offset: 0, forceRefresh: true);

      // Assert: getPersonalizedVideos called twice (not just once from cache)
      verify(() => mockSupabaseService.getPersonalizedVideos(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).called(2);
    });

    /// Test 6: Handles errors gracefully, returns empty list
    test('returns empty list when SupabaseService throws error', () async {
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

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []);

      // Act
      final result = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: Returns empty list on error
      expect(result, isEmpty);
    });

    /// Test 7: Calculates correct fetch amounts with buffer
    test('calls SupabaseService with fetch amounts adjusted for DEDUP_BUFFER', () async {
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

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []);

      // Act: Fetch with limit=50
      await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: Verify fetch amounts
      // personalized: ceil(50 * 0.40 * 1.15) = 23
      // following: ceil(50 * 0.30 * 1.15) = 18
      // trending: ceil(50 * 0.20 * 1.15) = 12
      // discovery: ceil(50 * 0.10 * 1.15) = 6
      verify(() => mockSupabaseService.getPersonalizedVideos(
            limit: 23,
            offset: 0,
          )).called(1);
      verify(() => mockSupabaseService.getFollowingVideos(
            limit: 18,
            offset: 0,
          )).called(1);
      verify(() => mockSupabaseService.getTrendingVideos(
            limit: 12,
            offset: 0,
          )).called(1);
      verify(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: 6,
      )).called(1);
    });

    /// Test 8: Handles empty feed from all sources
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

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []);

      // Act
      final result = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert
      expect(result, isEmpty);
    });

    /// Test 9: Handles partial data (some sources empty)
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

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => []); // Empty

      // Act
      final result = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: Returns videos from non-empty sources
      expect(result.length, equals(2));
      expect(result.map((v) => v['id']), containsAll(['p-1', 't-1']));
    });

    /// Test 10: Preserves video source information in result
    test('tags videos with source and includes source in result', () async {
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

      when(() => mockSupabaseService.getRandomDiscoveryVideos(
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => [videoFromDiscovery]);

      // Act
      final result = await homeFeedService.getHomeFeed(limit: 50, offset: 0);

      // Assert: Each video has correct source tag
      final personalizedResult = result.firstWhere((v) => v['id'] == 'p-1');
      expect(personalizedResult['source'], equals('personalized'));

      final followingResult = result.firstWhere((v) => v['id'] == 'f-1');
      expect(followingResult['source'], equals('following'));

      final trendingResult = result.firstWhere((v) => v['id'] == 't-1');
      expect(trendingResult['source'], equals('trending'));

      final discoveryResult = result.firstWhere((v) => v['id'] == 'd-1');
      expect(discoveryResult['source'], equals('discovery'));
    });
  });
}

