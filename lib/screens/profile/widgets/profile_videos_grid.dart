import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/models/my_video.dart';
import 'package:beat_that/screens/profile/widgets/profile_video_grid_item.dart';
import 'package:beat_that/routes/app_router.dart';

/// A reusable widget that displays a grid of user's videos with improved spacing and balance.
///
/// Features:
/// - 2-column grid layout
/// - Responsive spacing and aspect ratio
/// - Video item interactions (open and delete)
/// - Theme-aware styling
///
/// Usage:
/// ```dart
/// ProfileVideosGrid(
///   videos: state.myVideos,
///   isDark: isDark,
///   onVideoDeleteConfirmed: (videoId) { /* handle delete */ },
/// )
/// ```
class ProfileVideosGrid extends StatelessWidget {
  /// List of videos to display
  final List<MyVideo> videos;

  /// Whether dark mode is enabled
  final bool isDark;

  /// The id of the tile currently being deleted.
  final String? deletingVideoId;

  /// Callback when a video is confirmed for deletion
  final Function(String videoId) onVideoDeleteConfirmed;

  const ProfileVideosGrid({
    super.key,
    required this.videos,
    required this.isDark,
    required this.deletingVideoId,
    required this.onVideoDeleteConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleteLocked = deletingVideoId != null;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final video = videos[index];
          return ProfileVideoGridItem(
            thumbnail: video,
            isDark: isDark,
            isDeleting: deletingVideoId == video.id,
            isDeleteLocked: isDeleteLocked,
            onOpen: () {
              HapticFeedback.mediumImpact();
              GoRouter.of(context).pushNamed(
                'edit-uploaded-video',
                extra: PlayUploadedVideoExtra(
                  videoPath: video.videoPath,
                  shouldShowEditButtons: false,
                ),
              );
            },
            onReviewIssuesTap: () {
              HapticFeedback.mediumImpact();
              GoRouter.of(context).pushNamed(
                'rejected-video-guidance',
                extra: RejectedVideoGuidanceExtra(videoTitle: video.title),
              );
            },
            onDeleteConfirmed: (videoId) {
              onVideoDeleteConfirmed(videoId);
            },
          );
        }, childCount: videos.length),
      ),
    );
  }
}
