import 'package:flutter/material.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/beat_shimmer.dart';

/// Sport grid item widget displaying a single sport
class SportGridItem extends StatelessWidget {
  const SportGridItem({super.key, required this.sport, this.onTap});

  final CategoryModel sport;
  final VoidCallback? onTap;

  static const _borderRadius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _borderRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: _borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SportImage(
                  imageUrl: sport.pathToImage,
                  sportName: sport.displayName,
                ),
                const _ImageGradient(),
                _SportName(name: sport.displayName),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SportImage extends StatelessWidget {
  const _SportImage({required this.imageUrl, required this.sportName});

  final String? imageUrl;
  final String sportName;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    if (url == null || url.isEmpty) {
      return const _ImagePlaceholder(icon: Icons.image_not_supported_outlined);
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const _ImageShimmer();
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Failed to load sport image: $sportName');
        debugPrint('Image URL: $url');
        debugPrint('Error: $error');

        return const _ImagePlaceholder(icon: Icons.broken_image_outlined);
      },
    );
  }
}

class _SportName extends StatelessWidget {
  const _SportName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class GameGridItem extends StatelessWidget {
  const GameGridItem({super.key, required this.game, this.onTap});

  final CategoryModel game;
  final VoidCallback? onTap;

  static const _borderRadius = BorderRadius.all(Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _borderRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: _borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _GameImage(imageUrl: game.pathToImage, gameName: game.name),
                const _ImageGradient(),
                _GameName(name: game.displayName),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameImage extends StatelessWidget {
  const _GameImage({required this.imageUrl, required this.gameName});

  final String? imageUrl;
  final String gameName;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    if (url == null || url.isEmpty) {
      return const _ImagePlaceholder(icon: Icons.image_not_supported_outlined);
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const _ImageShimmer();
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Failed to load image for $gameName');
        debugPrint('Image URL: $url');
        debugPrint('Error: $error');

        return const _ImagePlaceholder(icon: Icons.broken_image_outlined);
      },
    );
  }
}

class _ImageShimmer extends StatelessWidget {
  const _ImageShimmer();

  @override
  Widget build(BuildContext context) {
    return const BeatShimmerFill();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ImageGradient extends StatelessWidget {
  const _ImageGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.4, 0.65, 1.0],
        ),
      ),
    );
  }
}

class _GameName extends StatelessWidget {
  const _GameName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
