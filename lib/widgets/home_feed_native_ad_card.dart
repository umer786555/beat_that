import 'package:beat_that/constants/ad_mob_ids.dart';
import 'package:beat_that/widgets/feed_native_ad_card.dart';
import 'package:flutter/material.dart';

class HomeFeedNativeAdCard extends StatelessWidget {
  const HomeFeedNativeAdCard({super.key, required this.slotIndex});

  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    return FeedNativeAdCard(
      slotIndex: slotIndex,
      androidAdUnitId: AdMobIds.androidHomeFeedNative,
      iosAdUnitId: AdMobIds.iosHomeFeedNative,
      debugPlacementName: 'home feed',
    );
  }
}
