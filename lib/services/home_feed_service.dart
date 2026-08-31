import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';

/// Service to orchestrate the home feed by blending multiple video sources
///
/// Implements a 40/30/20/10 blending algorithm:
/// - 40% Personalized (user's engaged categories)
/// - 30% Following (videos from followed users)
/// - 20% Trending (best-rated videos from last 7 days)
/// - 10% Discovery (random videos from unwatched categories)
///
/// Features:
/// - Parallel API calls for efficiency
/// - Deduplication by video ID
/// - Composite scoring to maintain feed quality
/// - Pagination support with independent source cursors
/// - Source-aware continuation across sparse datasets
class HomeFeedService {
  final supabaseService = locator<SupabaseService>();

  static const int _maxContinuationAttempts = 4;

  /// Weights for feed blending (must sum to 1.0)
  static const double PERSONALIZED_WEIGHT = 0.40;
  static const double FOLLOWING_WEIGHT = 0.30;
  static const double TRENDING_WEIGHT = 0.20;
  static const double DISCOVERY_WEIGHT = 0.10;

  /// Buffer multiplier for deduplication (fetch a small cushion for overlap)
  static const double DEDUP_BUFFER = 1.05;

  /// Fetch the next unseen batch for an existing home-feed session.
  ///
  /// Starts from [cursor], filters out any videos already present in
  /// [seenVideoIds], and keeps advancing until it collects up to [limit]
  /// unique videos or the source-aware cursor is exhausted.
  Future<Map<String, dynamic>> getHomeFeedContinuation({
    required Set<String> seenVideoIds,
    HomeFeedCursor cursor = const HomeFeedCursor.initial(),
    int limit = 20,
  }) async {
    final collectedVideos = <SportVideo>[];
    final mutableSeenIds = <String>{...seenVideoIds};
    var nextCursor = cursor;

    for (var attempt = 0; attempt < _maxContinuationAttempts; attempt++) {
      if (collectedVideos.length >= limit || !nextCursor.hasMoreContent) {
        break;
      }

      final batchResult = await _getHomeFeedBatch(
        cursor: nextCursor,
        limit: limit,
        seenVideoIds: mutableSeenIds,
      );
      final batch = List<SportVideo>.from(batchResult['videos'] as List<dynamic>);
      nextCursor = batchResult['nextCursor'] as HomeFeedCursor;

      if (batch.isEmpty) {
        break;
      }

      for (final video in batch) {
        final videoId = video.id;
        if (mutableSeenIds.contains(videoId)) {
          continue;
        }

        mutableSeenIds.add(videoId);
        collectedVideos.add(video);

        if (collectedVideos.length >= limit) {
          break;
        }
      }

      // A short blended batch is not enough to prove the feed is exhausted.
      // Some sources can be sparse while later offsets still contain videos.
      // Continue until the source-aware cursor says every source is exhausted.
    }

    return {
      'videos': collectedVideos,
      'nextCursor': nextCursor,
      'hasMoreContent': nextCursor.hasMoreContent,
    };
  }

  Future<Map<String, dynamic>> _getHomeFeedBatch({
    required HomeFeedCursor cursor,
    required int limit,
    required Set<String> seenVideoIds,
  }) async {
    if (!cursor.hasMoreContent) {
      return {
        'videos': const <SportVideo>[],
        'nextCursor': cursor,
      };
    }

    final personalizedCount = _weightedSourceCount(limit, PERSONALIZED_WEIGHT);
    final followingCount = _weightedSourceCount(limit, FOLLOWING_WEIGHT);
    final trendingCount = _weightedSourceCount(limit, TRENDING_WEIGHT);
    final discoveryCount = _weightedSourceCount(limit, DISCOVERY_WEIGHT);

    print(
      '📊 HomeFeed: cursor(p=${cursor.personalizedOffset}, f=${cursor.followingOffset}, t=${cursor.trendingOffset}) fetch personalized=$personalizedCount, following=$followingCount, trending=$trendingCount, discovery=$discoveryCount',
    );

    final primaryResults = await Future.wait<List<SportVideo>>([
      if (cursor.hasMorePersonalized)
        supabaseService.getPersonalizedVideos(
          limit: personalizedCount,
          offset: cursor.personalizedOffset,
        )
      else
        Future.value(<SportVideo>[]),
      if (cursor.hasMoreFollowing)
        supabaseService.getFollowingVideos(
          limit: followingCount,
          offset: cursor.followingOffset,
        )
      else
        Future.value(<SportVideo>[]),
      if (cursor.hasMoreTrending)
        supabaseService.getTrendingVideos(
          limit: trendingCount,
          offset: cursor.trendingOffset,
        )
      else
        Future.value(<SportVideo>[]),
    ]);

    final personalizedVideos = primaryResults[0];
    final followingVideos = primaryResults[1];
    final trendingVideos = primaryResults[2];

    final discoveryExcludedIds = <String>{
      ...seenVideoIds,
      ...personalizedVideos.map((video) => video.id),
      ...followingVideos.map((video) => video.id),
      ...trendingVideos.map((video) => video.id),
    };

    final discoveryVideos = cursor.hasMoreDiscovery
        ? await supabaseService.getDiscoveryVideos(
            limit: discoveryCount,
            excludedVideoIds: discoveryExcludedIds,
          )
        : <SportVideo>[];

    print(
      '✓ Fetched: personalized=${personalizedVideos.length}, following=${followingVideos.length}, trending=${trendingVideos.length}, discovery=${discoveryVideos.length}',
    );

    final blendedFeed = _blendFeeds(
      personalizedVideos,
      followingVideos,
      trendingVideos,
      discoveryVideos,
      limit,
    );

    final nextCursor = cursor.copyWith(
      personalizedOffset:
          cursor.personalizedOffset + personalizedVideos.length,
      followingOffset: cursor.followingOffset + followingVideos.length,
      trendingOffset: cursor.trendingOffset + trendingVideos.length,
      hasMorePersonalized: _sourceHasMore(
        cursor.hasMorePersonalized,
        personalizedVideos.length,
        personalizedCount,
      ),
      hasMoreFollowing: _sourceHasMore(
        cursor.hasMoreFollowing,
        followingVideos.length,
        followingCount,
      ),
      hasMoreTrending: _sourceHasMore(
        cursor.hasMoreTrending,
        trendingVideos.length,
        trendingCount,
      ),
      hasMoreDiscovery: _sourceHasMore(
        cursor.hasMoreDiscovery,
        discoveryVideos.length,
        discoveryCount,
      ),
    );

    return {
      'videos': blendedFeed,
      'nextCursor': nextCursor,
    };
  }

  int _weightedSourceCount(int limit, double weight) {
    return (limit * weight * DEDUP_BUFFER).ceil();
  }

  bool _sourceHasMore(bool wasAvailable, int resultCount, int requestCount) {
    if (!wasAvailable || requestCount <= 0) {
      return false;
    }

    return resultCount >= requestCount;
  }

  /// Blend videos from 4 sources with deduplication and composite scoring
  ///
  /// Algorithm:
  /// 1. Tag each video with its source
  /// 2. Merge all videos
  /// 3. Deduplicate by video ID (keep first)
  /// 4. Calculate composite score = (source_weight + popularity_factor)
  /// 5. Sort by composite score descending
  /// 6. Return top 'limit' videos
  List<SportVideo> _blendFeeds(
    List<SportVideo> personalizedVideos,
    List<SportVideo> followingVideos,
    List<SportVideo> trendingVideos,
    List<SportVideo> discoveryVideos,
    int limit,
  ) {
    // Tag each video with source and weight
    final taggedPersonalized = _tagVideos(
      personalizedVideos,
      'personalized',
      PERSONALIZED_WEIGHT,
      0,
    );
    final taggedFollowing = _tagVideos(
      followingVideos,
      'following',
      FOLLOWING_WEIGHT,
      1,
    );
    final taggedTrending = _tagVideos(
      trendingVideos,
      'trending',
      TRENDING_WEIGHT,
      2,
    );
    final taggedDiscovery = _tagVideos(
      discoveryVideos,
      'discovery',
      DISCOVERY_WEIGHT,
      3,
    );

    // Merge all videos (preserves order from tagging)
    final allVideos = [
      ...taggedPersonalized,
      ...taggedFollowing,
      ...taggedTrending,
      ...taggedDiscovery,
    ];

    // Deduplicate by video ID (keep first occurrence)
    final seenIds = <String>{};
    final deduplicatedVideos = <SportVideo>[];

    for (final video in allVideos) {
      final videoId = video.id;
      if (!seenIds.contains(videoId)) {
        seenIds.add(videoId);
        deduplicatedVideos.add(video);
      }
    }

    print(
      '📊 Deduplication: ${allVideos.length} → ${deduplicatedVideos.length}',
    );

    // Sort by composite score (descending)
    deduplicatedVideos.sort((a, b) {
      final scoreA = a.compositeScore ?? 0;
      final scoreB = b.compositeScore ?? 0;
      return scoreB.compareTo(scoreA);
    });

    // Return top 'limit' videos
    final finalFeed = deduplicatedVideos.take(limit).toList();

    // Debug: print URLs in final feed
    for (final video in finalFeed) {
      final videoId = video.id;
      final thumbnailUrl = video.thumbnailUrl;
      print('📸 Final feed video $videoId: thumbnailUrl=$thumbnailUrl');
    }

    return finalFeed;
  }

  /// Tag videos with source, weight, and composite score
  ///
  /// Composite Score = source_weight + popularity_factor
  /// Where popularity_factor is normalized bayesian_score (0.0-1.0)
  List<SportVideo> _tagVideos(
    List<SportVideo> videos,
    String source,
    double sourceWeight,
    int sourceOrder,
  ) {
    return videos.map((video) {
      // Normalize bayesian_score to 0.0-1.0 (assuming max score around 100)
      final bayesianScore = video.bayesianScore;
      final popularityFactor = (bayesianScore / 100).clamp(0.0, 1.0);

      // Composite score = source weight + scaled popularity
      // Source weight (0.40, 0.30, 0.20, 0.10) + popularity (0.0-0.2)
      final compositeScore =
          sourceWeight + (popularityFactor * 0.2); // 0.2 = max popularity boost

      return video.copyWith(
        source: source,
        sourceOrder: sourceOrder,
        compositeScore: compositeScore,
      );
    }).toList();
  }

}
