import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/bloc/follow_counts_cubit.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/creator_profile/bloc/creator_profile_bloc.dart';
import 'package:beat_that/screens/profile/widgets/video_thumbnail_item.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CreatorProfileScreen extends StatelessWidget {
  const CreatorProfileScreen({super.key, required this.userId});

  final String userId;

  bool _shouldLoadMore(
    ScrollNotification notification,
    CreatorProfileLoaded state,
  ) {
    if (notification.depth != 0 ||
        state.isLoadingMore ||
        !state.hasMoreVideos ||
        state.videos.isEmpty ||
        notification.metrics.maxScrollExtent <= 0) {
      return false;
    }

    return notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 300;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) =>
          CreatorProfileBloc(userId: userId)
            ..add(const LoadCreatorProfileEvent()),
      child: BlocPresentationListener<CreatorProfileBloc, CreatorProfilePresentationEvent>(
        listener: (context, event) {
          switch (event) {
            case CreatorProfileFollowStatusUpdatedEvent():
              // Refresh shared counts instead of reaching into ProfileBloc.
              // Creator profiles are opened from multiple routes, so this
              // screen must not depend on the current profile feature scope.
              context.read<FollowCountsCubit>().refresh();
            case CreatorProfileFollowStatusErrorEvent():
              showErrorSnackBar(context, message: event.message);
          }
        },
        child: BlocBuilder<CreatorProfileBloc, CreatorProfileState>(
          builder: (context, state) {
            if (state is CreatorProfileLoading ||
                state is CreatorProfileInitial) {
              return const BeatLoadingScreen(message: 'Loading profile...');
            }

            if (state is CreatorProfileError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Creator Profile')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: isDark
                              ? AppColors.cyan
                              : AppColors.electricMagenta,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context.read<CreatorProfileBloc>().add(
                              const LoadCreatorProfileEvent(),
                            );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final loadedState = state as CreatorProfileLoaded;

            return Scaffold(
              appBar: AppBar(title: Text(loadedState.profile.username)),
              body: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_shouldLoadMore(notification, loadedState)) {
                    context.read<CreatorProfileBloc>().add(
                      const LoadMoreCreatorProfileVideosEvent(),
                    );
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.cyan
                                          : AppColors.electricMagenta,
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      loadedState.profile.profileUrl != null &&
                                          loadedState
                                              .profile
                                              .profileUrl!
                                              .isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            loadedState.profile.profileUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.error_outline,
                                                    size: 40,
                                                    color: isDark
                                                        ? AppColors.cyan
                                                        : AppColors
                                                              .electricMagenta,
                                                  );
                                                },
                                          ),
                                        )
                                      : Icon(
                                          Icons.person,
                                          size: 40,
                                          color: isDark
                                              ? AppColors.cyan
                                              : AppColors.electricMagenta,
                                        ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loadedState.profile.username,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),

                                      if (!loadedState.isOwnProfile) ...[
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed:
                                              loadedState.isUpdatingFollow
                                              ? null
                                              : () {
                                                  HapticFeedback.mediumImpact();
                                                  context
                                                      .read<
                                                        CreatorProfileBloc
                                                      >()
                                                      .add(
                                                        const ToggleFollowStatusEvent(),
                                                      );
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                loadedState.isFollowing
                                                ? Colors.transparent
                                                : (isDark
                                                      ? AppColors.cyan
                                                      : AppColors
                                                            .electricMagenta),
                                            foregroundColor:
                                                loadedState.isFollowing
                                                ? (isDark
                                                      ? AppColors.cyan
                                                      : AppColors
                                                            .electricMagenta)
                                                : Colors.white,
                                            side: BorderSide(
                                              color: isDark
                                                  ? AppColors.cyan
                                                  : AppColors.electricMagenta,
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10,
                                            ),
                                          ),
                                          child: loadedState.isUpdatingFollow
                                              ? SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          loadedState
                                                                  .isFollowing
                                                              ? (isDark
                                                                    ? AppColors
                                                                          .cyan
                                                                    : AppColors
                                                                          .electricMagenta)
                                                              : Colors.white,
                                                        ),
                                                  ),
                                                )
                                              : Text(
                                                  loadedState.isFollowing
                                                      ? 'Following'
                                                      : 'Follow',
                                                ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Divider(
                              color: isDark
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (loadedState.videos.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'No videos uploaded yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final thumbnail = loadedState.videos[index];
                          return VideoThumbnailItem(
                            thumbnail: thumbnail,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              GoRouter.of(context).pushNamed(
                                'play-video',
                                extra: PlayUploadedVideoExtra(
                                  videoPath: thumbnail.videoPath,
                                  shouldShowEditButtons: false,
                                ),
                              );
                            },
                          );
                        }, childCount: loadedState.videos.length),
                      ),
                    if (loadedState.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
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
}
