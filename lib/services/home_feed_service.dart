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
/// - Pagination support with offset
/// - Caching to reduce redundant API calls
class HomeFeedService {
  final supabaseService = locator<SupabaseService>();

  /// Weights for feed blending (must sum to 1.0)
  static const double PERSONALIZED_WEIGHT = 0.40;
  static const double FOLLOWING_WEIGHT = 0.30;
  static const double TRENDING_WEIGHT = 0.20;
  static const double DISCOVERY_WEIGHT = 0.10;

  /// Buffer multiplier for deduplication (fetch extra to account for duplicates)
  static const double DEDUP_BUFFER = 1.15;

  /// Cache of fetched feeds by offset
  final Map<int, List<Map<String, dynamic>>> _feedCache = {};

  /// Get blended home feed with 40/30/20/10 distribution
  ///
  /// Parameters:
  /// - [limit]: Number of videos to return (default: 50)
  /// - [offset]: Pagination offset for sequential fetches (default: 0)
  /// - [forceRefresh]: Bypass cache and fetch fresh data (default: false)
  ///
  /// Returns:
  /// - List of videos blended from 4 sources and sorted by composite score
  /// - Empty list if an error occurs or no videos available
  ///
  /// Algorithm:
  /// 1. Calculate fetch amounts: (target * weight * buffer)
  /// 2. Fetch all 4 sources in PARALLEL for efficiency
  /// 3. Deduplicate by video ID (keep first occurrence)
  /// 4. Calculate composite score for each video
  /// 5. Sort by composite score (descending)
  /// 6. Return top 'limit' videos
  /// 7. Cache result for this offset
  Future<List<Map<String, dynamic>>> getHomeFeed({
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    try {
      print('📺 HomeFeed: Fetching limit=$limit, offset=$offset');

      // Check cache first (unless forceRefresh)
      if (_feedCache.containsKey(offset) && !forceRefresh) {
        print('✓ HomeFeed: Serving from cache (offset=$offset)');
        return _feedCache[offset]!;
      }

      // Step 1: Calculate exact fetch amounts with dedup buffer
      final personalizedCount =
          (limit * PERSONALIZED_WEIGHT * DEDUP_BUFFER).ceil();
      final followingCount = (limit * FOLLOWING_WEIGHT * DEDUP_BUFFER).ceil();
      final trendingCount = (limit * TRENDING_WEIGHT * DEDUP_BUFFER).ceil();
      final discoveryCount = (limit * DISCOVERY_WEIGHT * DEDUP_BUFFER).ceil();

      print(
          '📊 HomeFeed: Fetching personalized=$personalizedCount, following=$followingCount, trending=$trendingCount, discovery=$discoveryCount');

      // Step 2: Fetch all 4 sources in PARALLEL
      final results = await Future.wait([
        supabaseService.getPersonalizedVideos(
          limit: personalizedCount,
          offset: offset,
        ),
        supabaseService.getFollowingVideos(
          limit: followingCount,
          offset: offset,
        ),
        supabaseService.getTrendingVideos(
          limit: trendingCount,
          offset: offset,
        ),
        supabaseService.getRandomDiscoveryVideos(
          limit: discoveryCount,
        ),
      ]);

      final personalizedVideos = results[0];
      final followingVideos = results[1];
      final trendingVideos = results[2];
      final discoveryVideos = results[3];

      print(
          '✓ Fetched: personalized=${personalizedVideos.length}, following=${followingVideos.length}, trending=${trendingVideos.length}, discovery=${discoveryVideos.length}');

      // Step 3: Blend videos with deduplication and scoring
      final blendedFeed = _blendFeeds(
        personalizedVideos,
        followingVideos,
        trendingVideos,
        discoveryVideos,
        limit,
      );

      // Step 4: Cache result
      _feedCache[offset] = blendedFeed;

      print('✓ HomeFeed: Returning ${blendedFeed.length} blended videos');
      return blendedFeed;
    } catch (e) {
      print('✗ HomeFeed Error: $e');
      return [];
    }
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
  List<Map<String, dynamic>> _blendFeeds(
    List<Map<String, dynamic>> personalizedVideos,
    List<Map<String, dynamic>> followingVideos,
    List<Map<String, dynamic>> trendingVideos,
    List<Map<String, dynamic>> discoveryVideos,
    int limit,
  ) {
    // Tag each video with source and weight
    final taggedPersonalized = _tagVideos(personalizedVideos, 'personalized',
        PERSONALIZED_WEIGHT, 0);
    final taggedFollowing =
        _tagVideos(followingVideos, 'following', FOLLOWING_WEIGHT, 1);
    final taggedTrending =
        _tagVideos(trendingVideos, 'trending', TRENDING_WEIGHT, 2);
    final taggedDiscovery =
        _tagVideos(discoveryVideos, 'discovery', DISCOVERY_WEIGHT, 3);

    // Merge all videos (preserves order from tagging)
    final allVideos = [
      ...taggedPersonalized,
      ...taggedFollowing,
      ...taggedTrending,
      ...taggedDiscovery,
    ];

    // Deduplicate by video ID (keep first occurrence)
    final seenIds = <String>{};
    final deduplicatedVideos = <Map<String, dynamic>>[];

    for (final video in allVideos) {
      final videoId = video['id'] as String;
      if (!seenIds.contains(videoId)) {
        seenIds.add(videoId);
        deduplicatedVideos.add(video);
      }
    }

    print('📊 Deduplication: ${allVideos.length} → ${deduplicatedVideos.length}');

    // Sort by composite score (descending)
    deduplicatedVideos.sort((a, b) {
      final scoreA = a['_composite_score'] as double;
      final scoreB = b['_composite_score'] as double;
      return scoreB.compareTo(scoreA);
    });

    // Return top 'limit' videos
    final finalFeed = deduplicatedVideos.take(limit).toList();
    
    // Debug: print URLs in final feed
    for (final video in finalFeed) {
      final videoId = video['id'] as String;
      final thumbnailUrl = video['thumbnail_url'] as String?;
      print('📸 Final feed video $videoId: thumbnail_url=$thumbnailUrl');
    }
    
    return finalFeed;
  }

  /// Tag videos with source, weight, and composite score
  /// 
  /// Composite Score = source_weight + popularity_factor
  /// Where popularity_factor is normalized bayesian_score (0.0-1.0)
  List<Map<String, dynamic>> _tagVideos(
    List<Map<String, dynamic>> videos,
    String source,
    double sourceWeight,
    int sourceOrder,
  ) {
    return videos.map((video) {
      // Normalize bayesian_score to 0.0-1.0 (assuming max score around 100)
      final bayesianScore = (video['bayesian_score'] as num?)?.toDouble() ?? 0.0;
      final popularityFactor = (bayesianScore / 100).clamp(0.0, 1.0);

      // Composite score = source weight + scaled popularity
      // Source weight (0.40, 0.30, 0.20, 0.10) + popularity (0.0-0.2)
      final compositeScore =
          sourceWeight + (popularityFactor * 0.2); // 0.2 = max popularity boost

      // Create new map with metadata (don't modify original)
      return {
        ...video,
        'source': source,
        '_source_order': sourceOrder,
        '_composite_score': compositeScore,
      };
    }).toList();
  }

  /// Clear the feed cache (call on logout or manual refresh)
  void clearCache() {
    _feedCache.clear();
    print('✓ HomeFeed cache cleared');
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_offsets': _feedCache.keys.toList(),
      'total_cached_videos': _feedCache.values.fold(0, (sum, list) => sum + list.length),
      'cache_size': _feedCache.length,
    };
  }
}
