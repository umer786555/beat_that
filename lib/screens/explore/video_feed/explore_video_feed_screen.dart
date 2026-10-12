import 'dart:async';

import 'package:beat_that/bloc/pooled_feed_playback.dart';
import 'package:beat_that/constants/ad_mob_ids.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/reporting/models/report_target.dart';
import 'package:beat_that/reporting/presentation/show_content_report_bottom_sheet.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_cubit.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_presentation_event.dart';
import 'package:beat_that/screens/explore/video_feed/explore_video_feed_state.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/ad_mob_consent_service.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:beat_that/widgets/pooled_feed_route_aware.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/pooled_video_surface.dart';
import 'package:beat_that/widgets/video_feed_chrome.dart';
import 'package:beat_that/widgets/video_overlay_action_button.dart';
import 'package:beat_that/widgets/video_rating_bottom_sheet.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'explore_video_feed_route_extra.dart';

class ExploreVideoFeedScreen extends StatefulWidget {
  const ExploreVideoFeedScreen({super.key, required this.extra});

  final ExploreVideoFeedExtra extra;

  @override
  State<ExploreVideoFeedScreen> createState() => _ExploreVideoFeedScreenState();
}

class _ExploreVideoFeedScreenState extends State<ExploreVideoFeedScreen>
    with PooledFeedRouteAware {
  static const int _firstInterstitialThreshold = 8;
  static const int _subsequentInterstitialInterval = 10;

  late final ExploreVideoFeedCubit _cubit;
  late final PageController _pageController;
  late final AdMobConsentService _consentService;
  bool _isChromeVisible = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  bool _isShowingInterstitial = false;
  int _lastVisitedIndex = 0;
  int _videosAdvancedCount = 0;
  int _nextInterstitialThreshold = _firstInterstitialThreshold;

  bool get _supportsInterstitialAds =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _interstitialAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AdMobIds.androidExploreVideoFeedInterstitial;
      case TargetPlatform.iOS:
        return AdMobIds.iosExploreVideoFeedInterstitial;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        throw UnsupportedError(
          'Interstitial ads are only supported on Android and iOS.',
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _cubit = ExploreVideoFeedCubit(
      initialVideos: widget.extra.videos,
      initialIndex: widget.extra.initialIndex,
      query: widget.extra.query,
      selectedSportId: widget.extra.selectedSportId,
      nextOffset: widget.extra.nextOffset,
      hasMoreContent: widget.extra.hasMoreContent,
      isRandomFeed: widget.extra.isRandomFeed,
      randomSeed: widget.extra.randomSeed,
      randomAfterId: widget.extra.randomAfterId,
      randomHasWrapped: widget.extra.randomHasWrapped,
    )..initialize();
    _pageController = PageController(initialPage: widget.extra.initialIndex);
    _consentService = locator<AdMobConsentService>();
    _consentService.addListener(_handleConsentStateChanged);
    _lastVisitedIndex = widget.extra.initialIndex;

    if (_consentService.canRequestAds) {
      _loadInterstitialAd();
    }
  }

  @override
  PooledFeedPlayback<Object?> get feedPlayback => _cubit;

  @override
  void dispose() {
    _consentService.removeListener(_handleConsentStateChanged);
    _disposeInterstitialAd();
    _pageController.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  void _handleConsentStateChanged() {
    if (!_consentService.canRequestAds) {
      _disposeInterstitialAd();
      return;
    }

    _loadInterstitialAd();
  }

  void _disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  Future<void> _loadInterstitialAd() async {
    if (!_supportsInterstitialAds ||
        !_consentService.canRequestAds ||
        _isInterstitialLoading ||
        _interstitialAd != null) {
      return;
    }

    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isInterstitialLoading = false;
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) => _cubit.onAdShown(),
            onAdDismissedFullScreenContent: (ad) {
              _isShowingInterstitial = false;
              _cubit.onAdClosed();
              ad.dispose();
              if (identical(_interstitialAd, ad)) {
                _interstitialAd = null;
              }
              unawaited(_loadInterstitialAd());
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isShowingInterstitial = false;
              _cubit.onAdClosed();
              ad.dispose();
              if (identical(_interstitialAd, ad)) {
                _interstitialAd = null;
              }
              debugPrint(
                'Failed to show explore video feed interstitial: $error',
              );
              unawaited(_loadInterstitialAd());
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          debugPrint(
            'Failed to load explore video feed interstitial ad: $error',
          );
        },
      ),
    );
  }

  Future<void> _handlePageChanged(
    ExploreVideoFeedCubit cubit,
    int index,
  ) async {
    _hideChrome();
    await cubit.onPageChanged(index);
    _trackForwardProgress(index);
    await _maybeShowInterstitial();
  }

  void _toggleChromeVisibility() {
    setState(() {
      _isChromeVisible = !_isChromeVisible;
    });
  }

  void _hideChrome() {
    if (!_isChromeVisible) {
      return;
    }

    setState(() {
      _isChromeVisible = false;
    });
  }

  void _trackForwardProgress(int index) {
    if (index > _lastVisitedIndex) {
      _videosAdvancedCount += index - _lastVisitedIndex;
    }

    _lastVisitedIndex = index;
  }

  Future<void> _maybeShowInterstitial() async {
    if (!_supportsInterstitialAds ||
        !_consentService.canRequestAds ||
        _isShowingInterstitial ||
        _videosAdvancedCount < _nextInterstitialThreshold) {
      return;
    }

    final interstitialAd = _interstitialAd;
    if (interstitialAd == null) {
      await _loadInterstitialAd();
      return;
    }

    _isShowingInterstitial = true;
    _nextInterstitialThreshold += _subsequentInterstitialInterval;
    _interstitialAd = null;
    interstitialAd.show();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child:
          BlocPresentationListener<
            ExploreVideoFeedCubit,
            ExploreVideoFeedPresentationEvent
          >(
            listener: (context, event) {
              switch (event) {
                case ExploreVideoFeedRatingSuccessEvent():
                  showSuccessSnackBar(context, message: event.message);
                case ExploreVideoFeedRatingErrorEvent():
                  showErrorSnackBar(context, message: event.message);
              }
            },
            child: BlocBuilder<ExploreVideoFeedCubit, ExploreVideoFeedState>(
              builder: (context, state) {
                final cubit = context.read<ExploreVideoFeedCubit>();
                final onTogglePlayback = cubit.togglePlayback;
                final onRetryActiveVideo = cubit.retryActiveVideo;
                final reportTargetId = cubit.reportTargetIdForIndex(
                  state.currentIndex,
                );

                return _ExploreVideoFeedView(
                  state: state,
                  pageController: _pageController,
                  isChromeVisible: _isChromeVisible,
                  slotFor: cubit.slotFor,
                  onPageChanged: (index) => _handlePageChanged(cubit, index),
                  onToggleChrome: _toggleChromeVisibility,
                  onTogglePlayback: onTogglePlayback,
                  onOpenRating: () => _showRatingSheet(
                    context,
                    cubit: cubit,
                    onSubmitRating: cubit.submitRating,
                  ),
                  onRetryActiveVideo: onRetryActiveVideo,
                  onBack: context.pop,
                  onReport: reportTargetId == null || reportTargetId.isEmpty
                      ? null
                      : () =>
                            _showReportSheet(context, videoId: reportTargetId),
                );
              },
            ),
          ),
    );
  }

  Future<void> _showRatingSheet(
    BuildContext context, {
    required ExploreVideoFeedCubit cubit,
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
                ExploreVideoFeedCubit,
                ExploreVideoFeedState,
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

  Future<void> _showReportSheet(
    BuildContext context, {
    required String videoId,
  }) async {
    final message = await showContentReportBottomSheet(
      context,
      target: ReportTarget.video(videoId),
    );
    if (!context.mounted || message == null) {
      return;
    }

    showSuccessSnackBar(context, message: message);
  }
}

class _ExploreVideoFeedView extends StatelessWidget {
  const _ExploreVideoFeedView({
    required this.state,
    required this.pageController,
    required this.isChromeVisible,
    required this.slotFor,
    required this.onPageChanged,
    required this.onToggleChrome,
    required this.onTogglePlayback,
    required this.onOpenRating,
    required this.onRetryActiveVideo,
    required this.onBack,
    required this.onReport,
  });

  final ExploreVideoFeedState state;
  final PageController pageController;
  final bool isChromeVisible;
  final ValueListenable<VideoSlot> Function(int index) slotFor;
  final Future<void> Function(int index) onPageChanged;
  final VoidCallback onToggleChrome;
  final void Function(int index) onTogglePlayback;
  final VoidCallback onOpenRating;
  final VoidCallback onRetryActiveVideo;
  final VoidCallback onBack;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: pageController,
              scrollDirection: Axis.vertical,
              itemCount: state.videos.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final video = state.videos[index];
                final isCurrentVideo = index == state.currentIndex;
                final errorMessage = isCurrentVideo ? state.errorMessage : null;

                return _VideoFeedPage(
                  key: ValueKey(video.id),
                  video: video,
                  slot: slotFor(index),
                  isCurrentVideo: isCurrentVideo,
                  errorMessage: errorMessage,
                  isLoadingMore:
                      state.isLoadingMore && index == state.videos.length - 1,
                  showChrome: isCurrentVideo && isChromeVisible,
                  onToggleChrome: onToggleChrome,
                  onTogglePlayback: () => onTogglePlayback(index),
                  currentUserRating: isCurrentVideo
                      ? state.currentUserRating
                      : null,
                  onOpenRating: isCurrentVideo ? onOpenRating : null,
                  onRetry: isCurrentVideo ? onRetryActiveVideo : null,
                );
              },
            ),
            VideoFeedChrome(
              isVisible: isChromeVisible,
              onBackPressed: onBack,
              onReportPressed: onReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoFeedPage extends StatelessWidget {
  const _VideoFeedPage({
    super.key,
    required this.video,
    required this.slot,
    required this.isCurrentVideo,
    required this.errorMessage,
    required this.isLoadingMore,
    required this.showChrome,
    required this.onToggleChrome,
    required this.onTogglePlayback,
    required this.currentUserRating,
    this.onOpenRating,
    this.onRetry,
  });

  final SportVideo video;
  final ValueListenable<VideoSlot> slot;
  final bool isCurrentVideo;
  final String? errorMessage;
  final bool isLoadingMore;
  final bool showChrome;
  final VoidCallback onToggleChrome;
  final VoidCallback onTogglePlayback;
  final int? currentUserRating;
  final VoidCallback? onOpenRating;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final title = video.title;
    final username = video.username ?? 'Unknown';
    final userId = video.userId;
    final description = video.description;
    final viewCount = video.viewCount;
    final rating = video.averageRating;
    final canRateVideo = video.ratingTargetId != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isCurrentVideo ? onToggleChrome : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<VideoSlot>(
            valueListenable: slot,
            builder: (context, slot, child) => PooledVideoSurface(
              slot: slot,
              thumbnailUrl: video.thumbnailUrl,
              showLoadingIndicator: isCurrentVideo,
            ),
          ),
          if (showChrome)
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
          ValueListenableBuilder<VideoSlot>(
            valueListenable: slot,
            builder: (context, slot, child) {
              final overlayMessage = videoErrorOverlayMessage(
                slot: slot,
                errorMessage: errorMessage,
                isCurrentVideo: isCurrentVideo,
              );
              if (overlayMessage != null && onRetry != null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          overlayMessage,
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
                );
              }

              if (!showChrome ||
                  slot.status != VideoSlotStatus.ready ||
                  slot.isPlaying ||
                  !isCurrentVideo) {
                return const SizedBox.shrink();
              }

              return Center(
                child: Container(
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
                ),
              );
            },
          ),
          if (showChrome)
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: canRateVideo ? 16 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: userId.isEmpty
                                  ? null
                                  : () {
                                      HapticFeedback.mediumImpact();
                                      context.pushNamed(
                                        'creator-profile',
                                        extra: CreatorProfileExtra(
                                          userId: userId,
                                        ),
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
                    ),
                    if (canRateVideo)
                      VideoOverlayActionButton(
                        icon: Icons.star_rounded,
                        label: currentUserRating == null
                            ? 'Rate'
                            : '${currentUserRating!}/10',
                        accentColor: Colors.amber,
                        onTap: onOpenRating,
                      ),
                  ],
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
