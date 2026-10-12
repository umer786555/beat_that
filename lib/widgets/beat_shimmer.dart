import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BeatShimmerFill extends StatelessWidget {
  const BeatShimmerFill({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surface,
      child: ColoredBox(color: colorScheme.surfaceContainerHighest),
    );
  }
}
