import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/reporting/models/report_target.dart';
import 'package:beat_that/reporting/presentation/show_content_report_bottom_sheet.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/video_rating_bottom_sheet.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../state/home_video_feed_cubit.dart';
import '../state/home_video_feed_state.dart';
import 'events/home_video_feed_presentation_event.dart';
import 'widgets/home_video_feed_page.dart';
import 'widgets/home_video_feed_controls.dart';

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
                            final userId = video.userId;

                            return HomeVideoFeedPage(
                              key: ValueKey(video.id),
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
                                onOpenCreatorProfile: userId.isEmpty
                                  ? null
                                  : () {
                                      HapticFeedback.mediumImpact();
                                      debugPrint(
                                        'Opening creator profile for userId: $userId',
                                      );
                                      context.pushNamed(
                                        'creator-profile',
                                        extra: CreatorProfileExtra(
                                          userId: userId,
                                        ),
                                      );
                                    },
                              onRetry: isCurrentVideo
                                  ? cubit.retryActiveVideo
                                  : null,
                            );
                          },
                        ),
                        HomeVideoFeedBackButton(onPressed: () => context.pop()),

                        HomeVideoFeedDropdownMenu(
                          onReportPressed: () async {
                            final videoId =
                                cubit.reportVideoIdForIndex(
                                  state.currentIndex,
                                ) ??
                                '';

                            final message = await showContentReportBottomSheet(
                              context,
                              target: ReportTarget.video(videoId),
                            );
                            if (!context.mounted || message == null) {
                              return;
                            }

                            showSuccessSnackBar(context, message: message);
                          },
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
