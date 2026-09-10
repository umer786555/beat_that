import 'package:beat_that/constants/ad_mob_ids.dart';
import 'package:beat_that/widgets/feed_native_ad_card.dart';
import 'package:flutter/material.dart';

class SportDetailsNativeAdCard extends StatelessWidget {
  const SportDetailsNativeAdCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FeedNativeAdCard(
      slotIndex: 0,
      androidAdUnitId: AdMobIds.androidSportDetailsNative,
      iosAdUnitId: AdMobIds.iosSportDetailsNative,
      debugPlacementName: 'sport details',
      useMediumTemplateOnAndroid: true,
      useMediumTemplateOnIos: true,
    );
  }
}
