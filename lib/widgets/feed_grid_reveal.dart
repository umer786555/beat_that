import 'package:beat_that/widgets/feed_grid_geometry.dart';
import 'package:flutter/widgets.dart';

/// Scrolls a lazily built feed grid until the card holding [targetKey] is visible.
///
/// Off-screen cards aren't built, so this jumps to [estimatedOffset] first and
/// then steps down a viewport at a time; ads between rows make the estimate low.
Future<void> revealFeedGridItem({
  required ScrollController controller,
  required GlobalKey targetKey,
  required double estimatedOffset,
  required bool Function() shouldContinue,
}) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    await WidgetsBinding.instance.endOfFrame;
    if (!shouldContinue() || !controller.hasClients) return;

    final targetContext = targetKey.currentContext;
    if (targetContext != null) {
      if (!targetContext.mounted) return;
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }

    final position = controller.position;
    if (attempt > 0 && position.pixels >= position.maxScrollExtent) return;

    final nextOffset = attempt == 0
        ? estimatedOffset
        : position.pixels + position.viewportDimension;
    position.jumpTo(
      nextOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }
}

/// Approximate scroll offset of [index] in a 2-column feed grid, ignoring ads.
///
/// [headerOffset] is the height of any slivers above the grid.
double estimateFeedGridOffset({
  required int index,
  required double gridWidth,
  double headerOffset = 0,
}) {
  final cardWidth = (gridWidth - 3 * kFeedGridSpacing) / 2;
  final rowExtent = cardWidth / kFeedGridChildAspectRatio + kFeedGridSpacing;
  return headerOffset + (index ~/ 2) * rowExtent;
}
