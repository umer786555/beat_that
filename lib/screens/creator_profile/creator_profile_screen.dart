import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/bloc/follow_counts_cubit.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/creator_profile/bloc/creator_profile_bloc.dart';
import 'package:beat_that/screens/creator_profile/widgets/blocking_overlay.dart';
import 'package:beat_that/screens/creator_profile/widgets/profile_header.dart';
import 'package:beat_that/screens/profile/widgets/video_thumbnail_item.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CreatorProfileScreen extends StatelessWidget {
  const CreatorProfileScreen({super.key, required this.userId});

  final String userId;

  // Constants
  static const double _scrollLoadMoreThreshold = 300;
  static const double _gridChildAspectRatio = 0.78;
  static const int _gridCrossAxisCount = 2;
  static const double _gridSpacing = 12;
  static const double _loadingIndicatorVerticalPadding = 20;

  void _popBlockedFlow(BuildContext context) {
    final router = GoRouter.of(context);

    if (router.canPop()) {
      router.pop();
    }

    if (router.canPop()) {
      router.pop();
    }
  }

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
        notification.metrics.maxScrollExtent - _scrollLoadMoreThreshold;
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
            print(
              '🟢 [CreatorProfileScreen] BlocBuilder called with state type: ${state.runtimeType}',
            );
            print('🟢 [CreatorProfileScreen] State: $state');

            if (state is CreatorProfileLoading ||
                state is CreatorProfileInitial) {
              print('🟢 [CreatorProfileScreen] Showing loading screen');
              return const BeatLoadingScreen(message: 'Loading profile...');
            }

            if (state is CreatorProfileError) {
              print(
                '🟢 [CreatorProfileScreen] Showing error screen: ${state.message}',
              );
              return ErrorScreen(
                message: state.message,
                primaryButtonText: 'Retry',
                primaryButtonCallback: () {
                  context.read<CreatorProfileBloc>().add(
                    const LoadCreatorProfileEvent(),
                  );
                },
                icon: Icons.error_outline,
                iconColor: isDark ? AppColors.cyan : AppColors.electricMagenta,
              );
            }

            print(
              '🟢 [CreatorProfileScreen] About to cast state to CreatorProfileLoaded',
            );
            final loadedState = state as CreatorProfileLoaded;
            print(
              '🟢 [CreatorProfileScreen] Cast successful. Profile: ${loadedState.profile.username}, isUserBlocked: ${loadedState.isUserBlocked}',
            );

            return Stack(
              children: [
                Scaffold(
                  appBar: AppBar(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    centerTitle: true,
                    title: Text(
                      loadedState.profile.username,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    actions: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        elevation: 8,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (String value) {
                          print(
                            '🟢 [CreatorProfileScreen] PopupMenuButton onSelected: $value',
                          );
                          if (value == 'block') {
                            print(
                              '🟢 [CreatorProfileScreen] Block selected. Profile ID: ${loadedState.profile.id}',
                            );
                            context.read<CreatorProfileBloc>().add(
                              BlockUserEvent(
                                userId: loadedState.profile.id ?? '',
                              ),
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'block',
                            child: Text(
                              'Block',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                          child: ProfileHeader(
                            username: loadedState.profile.username,
                            profileUrl: loadedState.profile.profileUrl,
                            isOwnProfile: loadedState.isOwnProfile,
                            isFollowing: loadedState.isFollowing,
                            isUpdatingFollow: loadedState.isUpdatingFollow,
                            isDark: isDark,
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
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridCrossAxisCount,
                                  mainAxisSpacing: _gridSpacing,
                                  crossAxisSpacing: _gridSpacing,
                                  childAspectRatio: _gridChildAspectRatio,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final video = loadedState.videos[index];
                              return VideoThumbnailItem(
                                thumbnail: video,
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  GoRouter.of(context).pushNamed(
                                    'play-video',
                                    extra: PlayUploadedVideoExtra(
                                      videoPath: video.videoPath,
                                      shouldShowEditButtons: false,
                                    ),
                                  );
                                },
                              );
                            }, childCount: loadedState.videos.length),
                          ),
                        if (loadedState.isLoadingMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: _loadingIndicatorVerticalPadding,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Blocking overlay
                if (loadedState.isUserBlocked)
                  BlockingOverlay(
                    title: 'User Blocked',
                    message:
                        'You have blocked this user.\nYou won\'t see their content.',
                    actionLabel: 'Go Back',
                    onActionPressed: () {
                      _popBlockedFlow(context);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
