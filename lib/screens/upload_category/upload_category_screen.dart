import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_bloc.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_event.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_state.dart';
import 'package:beat_that/widgets/beat_shimmer.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UploadCategoryScreen extends StatelessWidget {
  const UploadCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UploadCategoryBloc, UploadCategoryState>(
      builder: (context, state) {
        if (state is UploadCategoryInitial || state is UploadCategoryLoading) {
          return const _LoadingView();
        }

        if (state is UploadCategoryError) {
          return ErrorScreen(
            message: state.message,
            primaryButtonText: 'Retry',
            primaryButtonCallback: () {
              context.read<UploadCategoryBloc>().add(
                const RetryUploadCategoryImagesEvent(),
              );
            },
            secondaryButtonText: 'Go Back',
            secondaryButtonCallback: () => context.pop(),
          );
        }

        final loadedState = state as UploadCategoryLoaded;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(child: _BackButton(onPressed: () => context.pop())),
            ),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                16,
                32,
              ),
              children: [
                const _Header(),
                const SizedBox(height: 24),
                ...loadedState.imageUrls.map((imageUrl) {
                  final category = _categoryFromImageUrl(imageUrl);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CategoryCard(
                      imageUrl: imageUrl,
                      category: category,
                      onTap: () => _openCategory(context, category),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  static _Category _categoryFromImageUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);

    final filename = uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : imageUrl;

    final id = filename.split('.').first.toLowerCase();

    switch (id) {
      case 'sports':
        return const _Category(
          id: 'sports',
          title: 'Sports',
          description: 'Show us what you can do.',
        );

      case 'gaming':
        return const _Category(
          id: 'gaming',
          title: 'Gaming',
          description: 'Share your best gaming moments.',
        );

      default:
        return _Category(
          id: id,
          title: _formatCategoryTitle(id),
          description: 'Choose this category to continue.',
        );
    }
  }

  static String _formatCategoryTitle(String id) {
    if (id.isEmpty) return 'Category';

    return id
        .replaceAll(RegExp(r'[-_]'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static void _openCategory(BuildContext context, _Category category) {
    final routeName = switch (category.id) {
      'sports' => 'sports-hub',
      'gaming' => 'gaming-hub',
      _ => null,
    };

    if (routeName == null) return;

    HapticFeedback.selectionClick();
    context.pushNamed(routeName);
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a category',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What kind of clip are you uploading?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.86),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 40,
          child: Icon(
            CupertinoIcons.chevron_back,
            size: 19,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(child: _BackButton(onPressed: () => context.pop())),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
            16,
            32,
          ),
          children: const [
            _Header(),
            SizedBox(height: 24),
            _LoadingCard(),
            SizedBox(height: 16),
            _LoadingCard(),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: const [
            BeatShimmerFill(),
            DecoratedBox(decoration: BoxDecoration(color: Color(0x10000000))),
            DecoratedBox(
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
            Positioned(
              left: 18,
              right: 16,
              bottom: 16,
              child: _LoadingCardContent(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCardContent extends StatelessWidget {
  const _LoadingCardContent();

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
              Container(
                width: 132,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 184,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const _ForwardButton(),
      ],
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.imageUrl,
    required this.category,
    required this.onTap,
  });

  final String imageUrl;
  final _Category category;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  static const _radius = 14.0;
  static const _animationDuration = Duration(milliseconds: 140);

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: _setPressed,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetworkImage(
                  imageUrl: widget.imageUrl,
                  label: widget.category.title,
                ),

                // Subtle overall tint keeps bright images from
                // overpowering the foreground content.
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x10000000)),
                ),

                // Softer cinematic gradient.
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

                Positioned(
                  left: 18,
                  right: 16,
                  bottom: 16,
                  child: _CardContent(category: widget.category),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.45,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                category.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.74),
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const _ForwardButton(),
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

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Image.network(
      imageUrl,
      semanticLabel: label,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const BeatShimmerFill();
      },
      errorBuilder: (_, _, _) {
        return ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 30,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

class _Category {
  const _Category({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}
