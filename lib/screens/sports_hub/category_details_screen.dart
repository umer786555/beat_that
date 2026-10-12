import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/screens/profile/widgets/upload_video_bottom_sheet.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/widgets/sport_details_native_ad_card.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:beat_that/widgets/subcategory_grid_item.dart';

import 'bloc/category_details_bloc.dart';

/// Sport details screen showing technique choices for a selected sport.
class CategoryDetailsScreen extends StatefulWidget {
  final CategoryModel categoryModel;

  const CategoryDetailsScreen({super.key, required this.categoryModel});

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  static const int _minimumCustomCategoryNameLength = 3;
  static const Set<String> _customCategoryNames = {
    'other_sports',
    'other_games',
  };

  final VideoPickerService _videoPickerService = locator<VideoPickerService>();
  final TextEditingController _customSportNameController =
      TextEditingController();

  @override
  void dispose() {
    _customSportNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SportDetailsBloc()
            ..add(LoadCategoryDetailsEvent(category: widget.categoryModel)),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            widget.categoryModel.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: BlocConsumer<SportDetailsBloc, SportDetailsState>(
          listener: (context, state) {
            if (state is CategoryDetailsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is CategoryDetailsLoading) {
              return const BeatLoadingScreen(
                message: 'Loading subcategories...',
              );
            }

            if (state is! CategoryDetailsLoaded) {
              return const SizedBox.shrink();
            }

            return _buildLoadedContent(context, state.sport);
          },
        ),
      ),
    );
  }

  Widget _buildLoadedContent(BuildContext context, CategoryModel loadedSport) {
    final shouldShowCustomSportField = _isCustomCategory(loadedSport.name);
    final hiddenCustomCategorySubcategory = _getHiddenCustomCategorySubcategory(
      loadedSport,
      shouldShowCustomSportField,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SportDetailsHeaderCard(sport: loadedSport),
        const SizedBox(height: 20),
        const Text(
          'Choose a technique',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the specific skill this video belongs to.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.greyDark,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        const SportDetailsNativeAdCard(),
        const SizedBox(height: 18),
        if (shouldShowCustomSportField)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _customSportNameController,
            builder: (context, value, _) {
              return _CustomSportNameField(
                controller: _customSportNameController,
                isContinueEnabled:
                    value.text.trim().length >=
                    _minimumCustomCategoryNameLength,
                onContinue: () => _handleCustomCategoryContinue(
                  context,
                  loadedSport,
                  hiddenCustomCategorySubcategory,
                ),
              );
            },
          ),
        if (!shouldShowCustomSportField)
          ..._buildSubcategoryItems(context, loadedSport),
      ],
    );
  }

  bool _isCustomCategory(String categoryName) {
    return _customCategoryNames.contains(categoryName);
  }

  String? _getHiddenCustomCategorySubcategory(
    CategoryModel loadedSport,
    bool shouldShowCustomSportField,
  ) {
    if (!shouldShowCustomSportField || loadedSport.subcategories.isEmpty) {
      return null;
    }

    return loadedSport.subcategories.first.name;
  }

  void _handleCustomCategoryContinue(
    BuildContext context,
    CategoryModel loadedSport,
    String? hiddenCustomCategorySubcategory,
  ) {
    final customSportName = _customSportNameController.text.trim();
    if (customSportName.length < _minimumCustomCategoryNameLength) {
      return;
    }

    FocusScope.of(context).unfocus();
    _showUploadOptions(
      context: context,
      loadedSport: loadedSport,
      subcategoryName: hiddenCustomCategorySubcategory,
      customSportName: customSportName,
    );
  }

  List<Widget> _buildSubcategoryItems(
    BuildContext context,
    CategoryModel loadedSport,
  ) {
    return [
      for (
        var index = 0;
        index < loadedSport.subcategories.length;
        index++
      ) ...[
        SubcategoryGridItem(
          subcategoryName: loadedSport.subcategories[index].name,
          onTap: () => _showUploadOptions(
            context: context,
            loadedSport: loadedSport,
            subcategoryName: loadedSport.subcategories[index].name,
          ),
        ),
        if (index != loadedSport.subcategories.length - 1)
          const SizedBox(height: 14),
      ],
    ];
  }

  Future<void> _showUploadOptions({
    required BuildContext context,
    required CategoryModel loadedSport,
    String? subcategoryName,
    String? customSportName,
  }) async {
    HapticFeedback.lightImpact();

    await showModalBottomSheet(
      context: context,
      builder: (_) => UploadVideoBottomSheet(
        onRecordVideoSelected: () async {
          final video = await _videoPickerService.pickCameraVideo();
          if (video != null && context.mounted) {
            GoRouter.of(context).pushNamed(
              'edit-uploaded-video',
              extra: PlayUploadedVideoExtra(
                videoPath: video.path,
                shouldShowEditButtons: true,
                sport: loadedSport,
                selectedSubcategory: subcategoryName,
                customSportName: customSportName,
              ),
            );
          }
        },
        onUploadFromGallerySelected: () async {
          final video = await _videoPickerService.pickGalleryVideo();
          if (video != null && context.mounted) {
            GoRouter.of(context).pushNamed(
              'edit-uploaded-video',
              extra: PlayUploadedVideoExtra(
                videoPath: video.path,
                shouldShowEditButtons: true,
                sport: loadedSport,
                selectedSubcategory: subcategoryName,
                customSportName: customSportName,
              ),
            );
          }
        },
      ),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

class _CustomSportNameField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onContinue;
  final bool isContinueEnabled;

  const _CustomSportNameField({
    required this.controller,
    required this.onContinue,
    required this.isContinueEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter a name',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us what this video is for before continuing.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.greyDark,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLength: 50,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Type the name',
            helperText: 'Enter at least 3 characters',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.green.withValues(alpha: 0.18),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.green.withValues(alpha: 0.18),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.green, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isContinueEnabled ? onContinue : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}

class _SportDetailsHeaderCard extends StatelessWidget {
  final CategoryModel sport;

  const _SportDetailsHeaderCard({required this.sport});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sport.pathToImage != null && sport.pathToImage!.isNotEmpty)
            _buildSportImage(sport.pathToImage!),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sport.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${sport.subcategories.length} techniques available',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.greyDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Choose one skill below, then record or upload the matching video.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.greyDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.sports_soccer, size: 36, color: Colors.grey),
    );
  }
}
