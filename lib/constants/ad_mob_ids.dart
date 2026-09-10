import 'package:flutter/foundation.dart';

class AdMobIds {
  const AdMobIds._();

  static const String _androidHomeFeedNativeTest =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _androidHomeFeedNativeProduction =
      'ca-app-pub-5368428898104194/3890362246';
  static const String _androidSportDetailsNativeTest =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _androidSportDetailsNativeProduction =
      'ca-app-pub-5368428898104194/2271630994';
  static const String _androidExploreFeedNativeTest =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _androidExploreFeedNativeProduction =
      'ca-app-pub-5368428898104194/2793892673';
  static const String _androidExploreVideoFeedInterstitialTest =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _androidExploreVideoFeedInterstitialProduction =
      'ca-app-pub-5368428898104194/1784063331';
  static const String _androidHomeVideoFeedInterstitialTest =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _androidHomeVideoFeedInterstitialProduction =
      'ca-app-pub-5368428898104194/4345657815';
  static const String _iosHomeFeedNativeTest =
      'ca-app-pub-3940256099942544/3986624511';
  static const String _iosHomeFeedNativeProduction =
      'ca-app-pub-5368428898104194/4354868856';
  static const String _iosSportDetailsNativeTest =
      'ca-app-pub-3940256099942544/3986624511';
  static const String _iosSportDetailsNativeProduction =
      'ca-app-pub-5368428898104194/1883146008';
  static const String _iosExploreFeedNativeTest =
      'ca-app-pub-3940256099942544/3986624511';
  static const String _iosExploreFeedNativeProduction =
      'ca-app-pub-5368428898104194/8720017097';
  static const String _iosExploreVideoFeedInterstitialTest =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _iosExploreVideoFeedInterstitialProduction =
      'ca-app-pub-5368428898104194/9470981664';
  static const String _iosHomeVideoFeedInterstitialTest =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _iosHomeVideoFeedInterstitialProduction =
      'ca-app-pub-5368428898104194/2302938081';

  static String get androidHomeFeedNative => kReleaseMode
      ? _androidHomeFeedNativeProduction
      : _androidHomeFeedNativeTest;

  static String get iosHomeFeedNative =>
      kReleaseMode ? _iosHomeFeedNativeProduction : _iosHomeFeedNativeTest;

  static String get androidSportDetailsNative => kReleaseMode
      ? _androidSportDetailsNativeProduction
      : _androidSportDetailsNativeTest;

  static String get iosSportDetailsNative => kReleaseMode
      ? _iosSportDetailsNativeProduction
      : _iosSportDetailsNativeTest;

  static String get androidExploreFeedNative => kReleaseMode
      ? _androidExploreFeedNativeProduction
      : _androidExploreFeedNativeTest;

  static String get iosExploreFeedNative => kReleaseMode
      ? _iosExploreFeedNativeProduction
      : _iosExploreFeedNativeTest;

  static String get androidExploreVideoFeedInterstitial => kReleaseMode
      ? _androidExploreVideoFeedInterstitialProduction
      : _androidExploreVideoFeedInterstitialTest;

  static String get iosExploreVideoFeedInterstitial => kReleaseMode
      ? _iosExploreVideoFeedInterstitialProduction
      : _iosExploreVideoFeedInterstitialTest;

  static String get androidHomeVideoFeedInterstitial => kReleaseMode
      ? _androidHomeVideoFeedInterstitialProduction
      : _androidHomeVideoFeedInterstitialTest;

  static String get iosHomeVideoFeedInterstitial => kReleaseMode
      ? _iosHomeVideoFeedInterstitialProduction
      : _iosHomeVideoFeedInterstitialTest;
}
