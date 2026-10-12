import 'dart:async';

import 'package:beat_that/bloc/pooled_feed_playback.dart';
import 'package:beat_that/constants/ad_mob_ids.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/reporting/models/report_target.dart';
import 'package:beat_that/reporting/presentation/show_content_report_bottom_sheet.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/ad_mob_consent_service.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/widgets/pooled_feed_route_aware.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/video_feed_chrome.dart';
import 'package:beat_that/widgets/video_rating_bottom_sheet.dart';
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

class _HomeVideoFeedScreenState extends State<HomeVideoFeedScreen>
    with PooledFeedRouteAware {
  static const int _firstInterstitialThreshold = 8;
  static const int _subsequentInterstitialInterval = 10;

  late final HomeVideoFeedCubit _cubit;
  late final PageController _pageController;
  late final AdMobConsentService _consentService;
  late final AuthService _authService;
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
    _cubit = HomeVideoFeedCubit(
      sessionId: widget.sessionId,
      initialIndex: widget.initialIndex,
    )..initialize();
    _pageController = PageController(initialPage: widget.initialIndex);
    _consentService = locator<AdMobConsentService>();
    _authService = locator<AuthService>();
    _consentService.addListener(_handleConsentStateChanged);
    _lastVisitedIndex = widget.initialIndex;

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

  bool _redirectGuestToAuth(BuildContext context) {
    if (_authService.hasFullAccountAccess()) {
      return false;
    }

    context.pushNamed('auth');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
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
                            final isCurrentVideo = index == state.currentIndex;
                            final errorMessage = isCurrentVideo
                                ? state.errorMessage
                                : null;
                            final userId = video.userId;

                            return HomeVideoFeedPage(
                              key: ValueKey(video.id),
                              video: video,
                              slot: cubit.slotFor(index),
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
                                  ? () {
                                      if (_redirectGuestToAuth(context)) {
                                        return;
                                      }

                                      _showRatingSheet(
                                        context,
                                        cubit: cubit,
                                        onSubmitRating: cubit.submitRating,
                                      );
                                    }
                                  : null,
                              onOpenCreatorProfile: userId.isEmpty
                                  ? null
                                  : () {
                                      if (_redirectGuestToAuth(context)) {
                                        return;
                                      }

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
                        VideoFeedChrome(
                          isVisible: _isChromeVisible,
                          onBackPressed: () => context.pop(),
                          onReportPressed: () async {
                            final reportTargetId =
                                cubit.reportTargetIdForIndex(
                                  state.currentIndex,
                                ) ??
                                '';

                            final message = await showContentReportBottomSheet(
                              context,
                              target: ReportTarget.video(reportTargetId),
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
