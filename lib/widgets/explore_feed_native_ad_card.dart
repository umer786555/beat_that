import 'package:beat_that/constants/ad_mob_ids.dart';
import 'package:beat_that/widgets/feed_native_ad_card.dart';
import 'package:flutter/material.dart';

class ExploreFeedNativeAdCard extends StatelessWidget {
  const ExploreFeedNativeAdCard({super.key, required this.slotIndex});

  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    return FeedNativeAdCard(
      slotIndex: slotIndex,
      androidAdUnitId: AdMobIds.androidExploreFeedNative,
      iosAdUnitId: AdMobIds.iosExploreFeedNative,
      debugPlacementName: 'explore feed',
    );
  }
}
