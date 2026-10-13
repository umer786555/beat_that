import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BeatShimmerFill extends StatelessWidget {
  const BeatShimmerFill({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = ColoredBox(color: colorScheme.surfaceContainerHighest);

    if (MediaQuery.disableAnimationsOf(context)) return fill;

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surface,
      child: fill,
    );
  }
}
