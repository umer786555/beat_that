import 'dart:async';

import 'package:beat_that/constants/ad_mob_ids.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/reporting/models/report_target.dart';
import 'package:beat_that/reporting/presentation/show_content_report_bottom_sheet.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/ad_mob_consent_service.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/video_rating_bottom_sheet.dart';
import 'package:beat_that/widgets/custom_back_button.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  static const int _firstInterstitialThreshold = 3;
  static const int _subsequentInterstitialInterval = 3;

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
        return AdMobIds.androidHomeVideoFeedInterstitial;
      case TargetPlatform.iOS:
        return AdMobIds.iosHomeVideoFeedInterstitial;
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
    _pageController = PageController(initialPage: widget.initialIndex);
    _consentService = locator<AdMobConsentService>();
    _consentService.addListener(_handleConsentStateChanged);
    _lastVisitedIndex = widget.initialIndex;

    if (_consentService.canRequestAds) {
      _loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    _consentService.removeListener(_handleConsentStateChanged);
    _disposeInterstitialAd();
    _pageController.dispose();
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
            onAdDismissedFullScreenContent: (ad) {
              _isShowingInterstitial = false;
              ad.dispose();
              if (identical(_interstitialAd, ad)) {
                _interstitialAd = null;
              }
              unawaited(_loadInterstitialAd());
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isShowingInterstitial = false;
              ad.dispose();
              if (identical(_interstitialAd, ad)) {
                _interstitialAd = null;
              }
              debugPrint('Failed to show home video feed interstitial: $error');
              unawaited(_loadInterstitialAd());
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          debugPrint('Failed to load home video feed interstitial ad: $error');
        },
      ),
    );
  }

  Future<void> _handlePageChanged(HomeVideoFeedCubit cubit, int index) async {
    HapticFeedback.lightImpact();
    _hideChrome();
    await cubit.onPageChanged(index);
    _trackForwardProgress(index);
    await _maybeShowInterstitial();
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
                          onPageChanged: (index) =>
                              _handlePageChanged(cubit, index),
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
                              showChrome: isCurrentVideo && _isChromeVisible,
                              onToggleChrome: _toggleChromeVisibility,
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
                        _HomeVideoFeedChrome(
                          isVisible: _isChromeVisible,
                          onBackPressed: () => context.pop(),
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

class _HomeVideoFeedChrome extends StatelessWidget {
  const _HomeVideoFeedChrome({
    required this.isVisible,
    required this.onBackPressed,
    required this.onReportPressed,
  });

  final bool isVisible;
  final VoidCallback onBackPressed;
  final VoidCallback onReportPressed;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: CustomBackButton(onPressed: onBackPressed),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: HomeVideoFeedDropdownMenu(onReportPressed: onReportPressed),
          ),
        ),
      ],
    );
  }
}
