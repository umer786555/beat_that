import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/models/sport.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/screens/profile/widgets/upload_video_bottom_sheet.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:beat_that/widgets/subcategory_grid_item.dart';
import 'bloc/sport_details_bloc.dart';

/// Sport details screen showing technique choices for a selected sport.
class SportDetailsScreen extends StatelessWidget {
  final Sport sport;
  final videoPickerService = locator<VideoPickerService>();

  SportDetailsScreen({super.key, required this.sport});

  Future<void> _showUploadOptions(
    BuildContext context,
    Sport loadedSport,
    String subcategoryName,
  ) async {
    HapticFeedback.lightImpact();

    await showModalBottomSheet(
      context: context,
      builder: (_) => UploadVideoBottomSheet(
        onRecordVideoSelected: () async {
          final video = await videoPickerService.pickCameraVideo();
          if (video != null && context.mounted) {
            GoRouter.of(context).pushNamed(
              'edit-uploaded-video',
              extra: PlayUploadedVideoExtra(
                videoPath: video.path,
                shouldShowEditButtons: true,
                sport: sport,
                selectedSubcategory: subcategoryName,
              ),
            );
          }
        },
        onUploadFromGallerySelected: () async {
          final video = await videoPickerService.pickGalleryVideo();
          if (video != null && context.mounted) {
            GoRouter.of(context).pushNamed(
              'edit-uploaded-video',
              extra: PlayUploadedVideoExtra(
                videoPath: video.path,
                shouldShowEditButtons: true,
                sport: loadedSport,
                selectedSubcategory: subcategoryName,
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SportDetailsBloc()..add(LoadSportDetailsEvent(sport: sport)),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            sport.displayName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: BlocConsumer<SportDetailsBloc, SportDetailsState>(
          listener: (context, state) {
            if (state is SportDetailsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is SportDetailsLoading) {
              return const BeatLoadingScreen(
                message: 'Loading subcategories...',
              );
            }

            if (state is SportDetailsLoaded) {
              final loadedSport = state.sport;
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
                  const SizedBox(height: 18),
                  for (
                    var index = 0;
                    index < loadedSport.subcategories.length;
                    index++
                  ) ...[
                    SubcategoryGridItem(
                      subcategoryName: loadedSport.subcategories[index].name,
                      index: index + 1,
                      onTap: () => _showUploadOptions(
                        context,
                        loadedSport,
                        loadedSport.subcategories[index].name,
                      ),
                    ),
                    if (index != loadedSport.subcategories.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              );
            }

            // Initial state
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _SportDetailsHeaderCard extends StatelessWidget {
  final Sport sport;

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
          if (sport.imageAssetPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                sport.imageAssetPath!,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(sport.icon, size: 36, color: AppColors.green),
            ),
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
}
