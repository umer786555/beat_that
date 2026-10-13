import 'package:flutter/widgets.dart';

const double kFeedGridSpacing = 6;
const double kFeedGridChildAspectRatio = 0.64;
const double kFeedCardRadius = 12;

/// Padding for the skeleton row shown below loaded cards while paging.
const kFeedGridLoadMorePadding = EdgeInsets.fromLTRB(
  kFeedGridSpacing,
  12,
  kFeedGridSpacing,
  0,
);

/// Delegate shared by Home and Explore video grids and their skeletons.
const kFeedGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: kFeedGridSpacing,
  mainAxisSpacing: kFeedGridSpacing,
  childAspectRatio: kFeedGridChildAspectRatio,
);
