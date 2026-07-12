import 'package:flutter/material.dart';

/// Reusable video feed card component for displaying videos in grid
class VideoFeedCard extends StatelessWidget {
  final String videoId;
  final String thumbnailUrl;
  final String? username;
  final int viewCount;
  final double rating;
  final String sourceType; // 'personalized', 'following', 'trending', 'discovery'
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const VideoFeedCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    this.username,
    required this.viewCount,
    required this.rating,
    required this.sourceType,
    required this.onTap,
    this.onLongPress,
  });

  /// Format view count as 1.2M, 500K, etc.
  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }



  @override
  Widget build(BuildContext context) {
    final formattedViews = _formatViewCount(viewCount);

    // Debug: log the thumbnail URL
    print('🖼️ VideoFeedCard build - videoId: $videoId, thumbnailUrl: $thumbnailUrl');

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          /// Main video thumbnail container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[300],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  /// Thumbnail image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ VideoFeedCard Image.network ERROR - videoId: $videoId');
                        print('   URL attempted: $thumbnailUrl');
                        print('   Error: $error');
                        print('   StackTrace: $stackTrace');
                        return Container(
                          color: Colors.grey[400],
                          child: const Center(
                            child: Icon(
                              Icons.video_library_outlined,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
                  ),

                  /// Play button overlay
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  /// Bottom gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  /// Bottom left info (username + view count + rating)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Username with avatar
                        if (username != null)
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey[600],
                                child: Text(
                                  username!.isNotEmpty
                                      ? username![0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '@$username',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),

                        /// View count + Rating
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility,
                              color: Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedViews,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),


                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
