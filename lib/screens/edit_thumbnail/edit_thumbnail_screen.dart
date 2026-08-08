import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/sport.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:beat_that/widgets/custom_snackbar.dart';
import 'package:beat_that/widgets/title_input_bottom_sheet.dart';

import 'package:go_router/go_router.dart';
import 'bloc/edit_thumbnail_bloc.dart';
import 'widgets/thumbnail_grid_item.dart';
import 'widgets/upload_progress_overlay.dart';

class EditThumbnailScreen extends StatelessWidget {
  final String videoPath;
  final Duration videoDuration;
  final Sport sport;
  final String? selectedSubcategory;

  const EditThumbnailScreen({
    super.key,
    required this.videoPath,
    required this.videoDuration,
    required this.sport,
    this.selectedSubcategory,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditThumbnailBloc(
        videoPath: videoPath,
        videoDuration: videoDuration,
        sport: sport,
        selectedSubcategory: selectedSubcategory,
      )..add(const InitialEvent()),
      child:
          BlocPresentationListener<
            EditThumbnailBloc,
            EditThumbnailPresentationEvent
          >(
            listener: (context, event) {
              switch (event) {
                case ThumbnailErrorEvent():
                  showErrorSnackBar(context, message: event.message);
                case VideoTooShortEvent():
                  showErrorSnackBar(context, message: event.message);
                  if (context.mounted) context.pop();
                case SaveSuccessEvent():
                  showSuccessSnackBar(context, message: event.message);
                  // Trigger ProfileBloc to refresh videos
                  context.read<ProfileBloc>().add(const RefreshVideosEvent());
                  // Pop the screen after showing snack bar
                  if (context.mounted) context.pop();
                  
              }
            },
            child: BlocListener<EditThumbnailBloc, EditThumbnailState>(
              listenWhen: (previous, current) =>
                  current is VideoUploadProgressState,
              listener: (context, state) {
                // Progress state is handled in the UI builder
              },
              child: BlocBuilder<EditThumbnailBloc, EditThumbnailState>(
                builder: (context, state) {
                  final isSaving = state is SavingVideoState;
                  final uploadProgress = state is VideoUploadProgressState
                      ? state
                      : null;

                  return Stack(
                    children: [
                      Scaffold(
                        appBar: AppBar(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          centerTitle: true,
                          title: Text(
                            'Edit Thumbnail',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        body: _buildBody(
                          state,
                          onBack: isSaving ? null : () => context.pop(),
                          onUpload: isSaving
                              ? null
                              : () {
                                  context.read<EditThumbnailBloc>().add(
                                    const CustomThumbnailSelectedEvent(),
                                  );
                                },
                        ),
                        floatingActionButton:
                            (state is ThumbnailsGeneratedState && !isSaving)
                            ? FloatingActionButton.extended(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  print(sport);
                                  _showTitleBottomSheet(
                                    context,
                                    onTitleSubmitted: (title) {
                                      context.read<EditThumbnailBloc>().add(
                                        SaveEvent(title: title),
                                      );
                                    },
                                  );
                                },
                                backgroundColor: AppColors.cyan,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text('Save'),
                              )
                            : null,
                      ),
                      // Upload progress overlay - DEV: Always visible for testing
                      UploadProgressOverlay(
                        progressPercent: uploadProgress?.progressPercent ?? 0,
                        sentBytes: uploadProgress?.sentBytes ?? 0,
                        totalBytes: uploadProgress?.totalBytes ?? 0,
                        isUploading: isSaving || uploadProgress != null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
    );
  }

  Widget _buildBody(
    EditThumbnailState state, {
    required VoidCallback? onBack,
    required VoidCallback? onUpload,
  }) {
    if (state is ThumbnailsGeneratedState) {
      return SingleChildScrollView(
        child: Column(
          children: [
            GridView.builder(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: state.thumbnails.length + 1,
              itemBuilder: (context, index) {
                // Last item is the upload placeholder
                if (index == state.thumbnails.length) {
                  return _buildUploadPlaceholder(context, onUpload);
                }

                return ThumbnailGridItem(
                  thumbnailData: state.thumbnails[index],
                  onTap: onUpload != null
                      ? () {
                          context.read<EditThumbnailBloc>().add(
                            ThumbnailSelectedEvent(selectedIndex: index),
                          );
                        }
                      : () {},
                  isLoading: state.isLoading,
                  isSelected: state.selectedIndex == index,
                );
              },
            ),
          ],
        ),
      );
    }

    return const Center(child: Text('Unknown state'));
  }

  Widget _buildUploadPlaceholder(
    BuildContext context,
    VoidCallback? onUploadTap,
  ) {
    return InteractiveButton(
      onTap: onUploadTap ?? () {},
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: onUploadTap != null
                ? AppColors.electricMagenta.withOpacity(0.6)
                : Colors.grey.withOpacity(0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: onUploadTap != null
                  ? AppColors.electricMagenta.withOpacity(0.7)
                  : Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload Custom',
              style: TextStyle(
                color: onUploadTap != null
                    ? AppColors.electricMagenta.withOpacity(0.7)
                    : Colors.grey.withOpacity(0.5),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTitleBottomSheet(
    BuildContext context, {
    required Function(String) onTitleSubmitted,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => TitleInputBottomSheet(
        onTitleSubmitted: (title) {
          Navigator.pop(context);
          onTitleSubmitted(title);
        },
      ),
    );
  }
}
