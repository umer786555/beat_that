import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/home/video_feed/home_video_feed_presentation_event.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/video_rating_bottom_sheet.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'home_video_feed_cubit.dart';
import 'home_video_feed_state.dart';

class HomeVideoFeedScreen extends StatefulWidget {
  const HomeVideoFeedScreen({
    super.key,
    required this.sessionId,
    required this.initialIndex,
  });

  final String sessionId;
  final int initialIndex;

  @override
  State<HomeVideoFeedScreen> createState() => _HomeVideoFeedScreenState();
}

class _HomeVideoFeedScreenState extends State<HomeVideoFeedScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeVideoFeedCubit(
        sessionId: widget.sessionId,
        initialIndex: widget.initialIndex,
      )..initialize(),
      child:
          BlocPresentationListener<
            HomeVideoFeedCubit,
            HomeVideoFeedPresentationEvent
          >(
            listener: (context, event) {
              switch (event) {
                case HomeVideoFeedRatingSuccessEvent():
                  showSuccessSnackBar(context, message: event.message);
                case HomeVideoFeedRatingErrorEvent():
                  showErrorSnackBar(context, message: event.message);
              }
            },
            child: BlocBuilder<HomeVideoFeedCubit, HomeVideoFeedState>(
              builder: (context, state) {
                final cubit = context.read<HomeVideoFeedCubit>();

                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light,
                  child: Scaffold(
                    backgroundColor: Colors.black,
                    body: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          itemCount: state.videos.length,
                          onPageChanged: (index) {
                            HapticFeedback.lightImpact();
                            cubit.onPageChanged(index);
                          },
                          itemBuilder: (context, index) {
                            final video = state.videos[index];
                            final controller = cubit.controllerFor(index);
                            final isCurrentVideo = index == state.currentIndex;
                            final errorMessage = isCurrentVideo
                                ? state.errorMessage
                                : null;

                            return _VideoFeedPage(
                              key: ValueKey(video['id'] ?? index),
                              video: video,
                              controller: controller,
                              isCurrentVideo: isCurrentVideo,
                              errorMessage: errorMessage,
                              isLoadingMore:
                                  state.isLoadingMore &&
                                  index == state.videos.length - 1,
                              onTogglePlayback: () =>
                                  cubit.togglePlayback(index),
                              currentUserRating: isCurrentVideo
                                  ? state.currentUserRating
                                  : null,
                              onOpenRating: isCurrentVideo
                                  ? () => _showRatingSheet(
                                      context,
                                      cubit: cubit,
                                      onSubmitRating: cubit.submitRating,
                                    )
                                  : null,
                              onRetry: isCurrentVideo
                                  ? cubit.retryActiveVideo
                                  : null,
                            );
                          },
                        ),
                        SafeArea(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                              ),
                              onPressed: () => context.pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }

  Future<void> _showRatingSheet(
    BuildContext context, {
    required HomeVideoFeedCubit cubit,
    required SubmitVideoRating onSubmitRating,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: cubit,
          child:
              BlocSelector<
                HomeVideoFeedCubit,
                HomeVideoFeedState,
                ({int? currentUserRating, bool isSubmittingRating})
              >(
                selector: (state) => (
                  currentUserRating: state.currentUserRating,
                  isSubmittingRating: state.isSubmittingRating,
                ),
                builder: (context, ratingState) {
                  return VideoRatingBottomSheet(
                    initialRating: ratingState.currentUserRating,
                    isSubmittingRating: ratingState.isSubmittingRating,
                    onSubmitRating: onSubmitRating,
                  );
                },
              ),
        );
      },
    );
  }
}

class _VideoFeedPage extends StatelessWidget {
  const _VideoFeedPage({
    super.key,
    required this.video,
    required this.controller,
    required this.isCurrentVideo,
    required this.errorMessage,
    required this.isLoadingMore,
    required this.onTogglePlayback,
    required this.currentUserRating,
    this.onOpenRating,
    this.onRetry,
  });

  final Map<String, dynamic> video;
  final VideoPlayerController? controller;
  final bool isCurrentVideo;
  final String? errorMessage;
  final bool isLoadingMore;
  final VoidCallback onTogglePlayback;
  final int? currentUserRating;
  final VoidCallback? onOpenRating;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final title = video['title'] as String? ?? 'Untitled';
    final username = video['username'] as String? ?? 'Unknown';
    final userId = video['user_id'] as String?;
    final description = video['description'] as String? ?? '';
    final viewCount = (video['view_count'] as num?)?.toInt() ?? 0;
    final rating = (video['average_rating'] as num?)?.toDouble() ?? 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isCurrentVideo ? onTogglePlayback : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller!,
              builder: (context, value, child) {
                if (value.isInitialized) {
                  return ColoredBox(
                    color: Colors.black,
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: value.size.width,
                          height: value.size.height,
                          child: VideoPlayer(controller!),
                        ),
                      ),
                    ),
                  );
                }

                return const _VideoPlaceholder();
              },
            )
          else
            const _VideoPlaceholder(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.70),
                ],
              ),
            ),
          ),
          if (controller == null && errorMessage != null && onRetry != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (controller != null)
            Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller!,
                builder: (context, value, child) {
                  if (!value.isInitialized ||
                      value.isPlaying ||
                      !isCurrentVideo) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  );
                },
              ),
            ),
          Positioned(
            left: 16,
            right: 88,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: userId == null
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          context.pushNamed(
                            'creator-profile',
                            extra: CreatorProfileExtra(userId: userId),
                          );
                        },
                  child: Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _VideoInfoChip(
                      icon: Icons.visibility_outlined,
                      label: _formatViewCount(viewCount),
                    ),
                    const SizedBox(width: 8),
                    _VideoInfoChip(
                      icon: Icons.star_rounded,
                      label: rating.toStringAsFixed(1),
                      iconColor: Colors.amber,
                    ),
                  ],
                ),
                if (isLoadingMore) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.green,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Loading more videos',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 48,
            child: SafeArea(
              top: false,
              child: _VideoActionButton(
                icon: Icons.star_rounded,
                label: currentUserRating == null
                    ? 'Rate'
                    : '${currentUserRating!}/10',
                accentColor: Colors.amber,
                onTap: onOpenRating,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _VideoActionButton extends StatelessWidget {
  const _VideoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InteractiveButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoInfoChip extends StatelessWidget {
  const _VideoInfoChip({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
