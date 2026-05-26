import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/models/sport.dart';
import 'package:beat_that/widgets/subcategory_grid_item.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/screens/profile/widgets/upload_video_bottom_sheet.dart';
import 'package:beat_that/routes/app_router.dart';
import 'bloc/sport_details_bloc.dart';

/// Sport Details screen - displays subcategories for a selected sport in a grid view
class SportDetailsScreen extends StatelessWidget {
  final Sport sport;
  final videoPickerService = locator<VideoPickerService>();

  SportDetailsScreen({super.key, required this.sport});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SportDetailsBloc()..add(LoadSportDetailsEvent(sport: sport)),
      child: Scaffold(
        appBar: AppBar(title: Text(sport.displayName), elevation: 0),
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
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          loadedSport.icon,
                          size: 32,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loadedSport.displayName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${loadedSport.subcategories.length} techniques',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.9,
                            ),
                        itemCount: loadedSport.subcategories.length,
                        itemBuilder: (context, index) {
                          return SubcategoryGridItem(
                            subcategoryName: loadedSport.subcategories[index].name,
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              // Show upload options bottom sheet
                              await showModalBottomSheet(
                                context: context,
                                builder: (_) => UploadVideoBottomSheet(
                                  onRecordVideoSelected: () async {
                                    final video = await videoPickerService
                                        .pickCameraVideo();
                                    if (video != null && context.mounted) {
                                      GoRouter.of(context).pushNamed(
                                        'edit-uploaded-video',
                                        extra: PlayUploadedVideoExtra(
                                          videoPath: video.path,
                                          shouldShowEditButtons: true,
                                          sport: sport,
                                          selectedSubcategory: loadedSport.subcategories[index].name,
                                        ),
                                      );
                                    }
                                  },
                                  onUploadFromGallerySelected: () async {
                                    print(
                                      'Upload from gallery selected for subcategory: ${loadedSport.subcategories[index].name}',
                                    );
                                    final video = await videoPickerService
                                        .pickGalleryVideo();
                                    if (video != null && context.mounted) {
                                      GoRouter.of(context).pushNamed(
                                        'edit-uploaded-video',
                                        extra: PlayUploadedVideoExtra(
                                          videoPath: video.path,
                                          shouldShowEditButtons: true,
                                          sport: sport,
                                          selectedSubcategory: loadedSport.subcategories[index].name,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
