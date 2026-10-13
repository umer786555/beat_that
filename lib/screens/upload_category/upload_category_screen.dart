import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_bloc.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_event.dart';
import 'package:beat_that/screens/upload_category/bloc/upload_category_state.dart';
import 'package:beat_that/screens/upload_category/models/upload_category.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/hub_page.dart';
import 'package:beat_that/widgets/hub_tile.dart';
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
        if (state is UploadCategoryError) {
          return ErrorScreen(
            message: state.message,
            primaryButtonText: AppStrings.retry,
            primaryButtonCallback: () {
              context.read<UploadCategoryBloc>().add(
                const RetryUploadCategoryImagesEvent(),
              );
            },
            secondaryButtonText: AppStrings.goBack,
            secondaryButtonCallback: () => context.pop(),
          );
        }

        return HubPage(
          title: AppStrings.chooseACategory,
          subtitle: AppStrings.uploadCategorySubtitle,
          sliver: switch (state) {
            UploadCategoryLoaded(:final categories) => _CategoryList(
              categories: categories,
            ),
            _ => const _CategoryListSkeleton(),
          },
        );
      },
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});

  final List<UploadCategory> categories;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final category in categories)
        HubTile(
          imageUrl: category.imageUrl,
          title: category.title,
          subtitle: category.description,
          showForwardButton: true,
          onTap: () {
            HapticFeedback.selectionClick();
            context.pushNamed(category.routeName);
          },
        ),
    ];

    return _CardColumn(cards: cards);
  }
}

class _CategoryListSkeleton extends StatelessWidget {
  const _CategoryListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _CardColumn(
      cards: [
        HubTileSkeleton(showSubtitle: true, showForwardButton: true),
        HubTileSkeleton(showSubtitle: true, showForwardButton: true),
      ],
    );
  }
}

class _CardColumn extends StatelessWidget {
  const _CardColumn({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, index) =>
          AspectRatio(aspectRatio: 16 / 9, child: cards[index]),
    );
  }
}
