import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/ad_mob_consent_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class FeedNativeAdCard extends StatefulWidget {
  const FeedNativeAdCard({
    super.key,
    required this.slotIndex,
    required this.androidAdUnitId,
    required this.iosAdUnitId,
    required this.debugPlacementName,
    this.useMediumTemplateOnAndroid = false,
    this.useMediumTemplateOnIos = true,
  });

  final int slotIndex;
  final String androidAdUnitId;
  final String iosAdUnitId;
  final String debugPlacementName;
  final bool useMediumTemplateOnAndroid;
  final bool useMediumTemplateOnIos;

  @override
  State<FeedNativeAdCard> createState() => _FeedNativeAdCardState();
}

class _FeedNativeAdCardState extends State<FeedNativeAdCard> {
  late final AdMobConsentService _consentService;
  NativeAd? _nativeAd;
  bool _isLoading = false;
  bool _didFailToLoad = false;

  static const double _smallAdContentHeight = 180;
  static const double _mediumAdContentHeight = 340;

  bool get _supportsAds =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _usesMediumTemplate =>
      (widget.useMediumTemplateOnAndroid &&
          defaultTargetPlatform == TargetPlatform.android) ||
      (widget.useMediumTemplateOnIos &&
          defaultTargetPlatform == TargetPlatform.iOS);

  String? get _adUnitId {
    if (!_supportsAds) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return widget.androidAdUnitId.isEmpty ? null : widget.androidAdUnitId;
      case TargetPlatform.iOS:
        return widget.iosAdUnitId.isEmpty ? null : widget.iosAdUnitId;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }

  TemplateType get _templateType =>
      _usesMediumTemplate ? TemplateType.medium : TemplateType.small;

  double get _adContentHeight =>
      _usesMediumTemplate ? _mediumAdContentHeight : _smallAdContentHeight;

  BoxConstraints get _adConstraints => _usesMediumTemplate
      ? const BoxConstraints(
          minWidth: 320,
          minHeight: 320,
          maxWidth: 400,
          maxHeight: 400,
        )
      : const BoxConstraints(
          minWidth: 320,
          minHeight: 90,
          maxWidth: 400,
          maxHeight: 200,
        );

  @override
  void initState() {
    super.initState();
    _consentService = locator<AdMobConsentService>();
    _consentService.addListener(_handleConsentStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_consentService.canRequestAds) {
      _loadNativeAd();
    }
  }

  void _handleConsentStateChanged() {
    if (!_consentService.canRequestAds) {
      _disposeNativeAd();
      _didFailToLoad = false;
      return;
    }

    _loadNativeAd();
  }

  Future<void> _loadNativeAd() async {
    final adUnitId = _adUnitId;
    if (adUnitId == null ||
        !_consentService.canRequestAds ||
        _isLoading ||
        _nativeAd != null) {
      return;
    }

    _isLoading = true;
    final theme = Theme.of(context);

    final nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: _templateType,
        mainBackgroundColor: theme.colorScheme.surface,
        cornerRadius: 16,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoading = false;
            _didFailToLoad = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'Failed to load ${widget.debugPlacementName} native ad slot '
            '${widget.slotIndex}: $error',
          );
          ad.dispose();

          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
            _didFailToLoad = true;
          });
        },
      ),
    );

    nativeAd.load();
  }

  void _disposeNativeAd() {
    final nativeAd = _nativeAd;
    if (nativeAd == null) {
      return;
    }

    nativeAd.dispose();
    _nativeAd = null;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _consentService.removeListener(_handleConsentStateChanged);
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adUnitId == null || !_consentService.canRequestAds) {
      return const SizedBox.shrink();
    }

    final nativeAd = _nativeAd;
    final shouldShowDebugPlaceholder =
        !kReleaseMode && (nativeAd == null) && (_isLoading || _didFailToLoad);

    if (nativeAd == null && !shouldShowDebugPlaceholder) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sponsored',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            if (nativeAd != null)
              SizedBox(
                width: double.infinity,
                height: _adContentHeight,
                child: Center(
                  child: ConstrainedBox(
                    constraints: _adConstraints,
                    child: AdWidget(ad: nativeAd),
                  ),
                ),
              )
            else
              SizedBox(
                height: _adContentHeight,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Ad unavailable right now',
                          style: theme.textTheme.bodySmall,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
