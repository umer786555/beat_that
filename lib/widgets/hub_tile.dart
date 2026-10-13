import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _radius = BorderRadius.all(Radius.circular(14));

/// Tappable image card with a bottom-left title, used by the upload category
/// screen (wide, with [subtitle] and forward arrow) and the hub grids.
class HubTile extends StatefulWidget {
  const HubTile({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showForwardButton = false,
  });

  final String? imageUrl;
  final String title;
  final String? subtitle;
  final bool showForwardButton;
  final VoidCallback onTap;

  @override
  State<HubTile> createState() => _HubTileState();
}

class _HubTileState extends State<HubTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle;

    // The ink overlay has no child, so expose the whole tile as one labelled
    // button instead of a bare tap target beside unlabelled text.
    return Semantics(
      button: true,
      label: subtitle == null ? widget.title : '${widget.title}. $subtitle',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: _buildTile(context, subtitle),
    );
  }

  Widget _buildTile(BuildContext context, String? subtitle) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: _TileFrame(
        background: _TileImage(imageUrl: widget.imageUrl),
        content: _TileContent(
          showForwardButton: widget.showForwardButton,
          title: Text(
            widget.title,
            maxLines: subtitle == null ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle(context, large: subtitle != null),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.74),
                    height: 1.3,
                  ),
                ),
        ),
        // Ink sits above the image so the ripple is visible.
        foreground: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: widget.onTap, onHighlightChanged: _setPressed),
        ),
      ),
    );
  }

  static TextStyle? _titleStyle(BuildContext context, {required bool large}) {
    final textTheme = Theme.of(context).textTheme;

    return (large ? textTheme.titleLarge : textTheme.titleSmall)?.copyWith(
      color: AppColors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: large ? -0.45 : -0.2,
      height: 1.15,
    );
  }
}

/// Shimmering placeholder matching [HubTile]'s layout.
class HubTileSkeleton extends StatelessWidget {
  const HubTileSkeleton({
    super.key,
    this.showSubtitle = false,
    this.showForwardButton = false,
  });

  final bool showSubtitle;
  final bool showForwardButton;

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      background: const BeatShimmerFill(),
      content: _TileContent(
        showForwardButton: showForwardButton,
        title: _SkeletonBar(width: showSubtitle ? 132 : 84, height: 18),
        subtitle: showSubtitle
            ? const _SkeletonBar(width: 184, height: 14, alpha: 0.42)
            : null,
      ),
    );
  }
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.background,
    required this.content,
    this.foreground,
  });

  final Widget background;
  final Widget content;
  final Widget? foreground;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _radius,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            // Subtle tint keeps bright images from overpowering the text,
            // and the gradient keeps the title legible.
            const ColoredBox(color: Color(0x10000000)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.25, 0.55, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0x18000000),
                    Color(0xC9000000),
                  ],
                ),
              ),
            ),
            Positioned(left: 16, right: 14, bottom: 14, child: content),
            if (foreground != null) Positioned.fill(child: foreground!),
          ],
        ),
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({
    required this.title,
    required this.showForwardButton,
    this.subtitle,
  });

  final Widget title;
  final Widget? subtitle;
  final bool showForwardButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (subtitle != null) ...[const SizedBox(height: 6), subtitle!],
            ],
          ),
        ),
        if (showForwardButton) ...[
          const SizedBox(width: 16),
          const _ForwardButton(),
        ],
      ],
    );
  }
}

class _ForwardButton extends StatelessWidget {
  const _ForwardButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        CupertinoIcons.chevron_forward,
        size: 17,
        color: AppColors.white,
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    this.alpha = 0.92,
  });

  final double width;
  final double height;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(height / 3),
      ),
    );
  }
}

class _TileImage extends StatelessWidget {
  const _TileImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    if (url == null || url.isEmpty) {
      return const _ImagePlaceholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const BeatShimmerFill();
      },
      errorBuilder: (_, _, _) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.3),
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 30,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
