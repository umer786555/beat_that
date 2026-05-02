import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'bloc/edit_thumbnail_bloc.dart';
import 'widgets/thumbnail_grid_item.dart';

class EditThumbnailScreen extends StatelessWidget {
  final String videoPath;
  final Duration videoDuration;

  const EditThumbnailScreen({
    super.key,
    required this.videoPath,
    required this.videoDuration,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditThumbnailBloc(videoPath: videoPath, videoDuration: videoDuration)..add(const InitialEvent()),
      child: BlocConsumer<EditThumbnailBloc, EditThumbnailState>(
        listener: (context, state) {
          if (state is ThumbnailErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Thumbnail'),
            ),
            body: _buildBody(state),
          );
        },
      ),
    );
  }

  Widget _buildBody(EditThumbnailState state) {
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
                  return _buildUploadPlaceholder(
                    context,
                    () {
                      // TODO: Implement custom thumbnail upload logic
                    },
                  );
                }
                
                return ThumbnailGridItem(
                  thumbnailData: state.thumbnails[index],
                  onTap: () {
                    context.read<EditThumbnailBloc>().add(ThumbnailSelectedEvent(selectedIndex: index));
                  },
                  isLoading: state.isLoading,
                  isSelected: state.selectedIndex == index,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: InteractiveButton(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.electricMagenta),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.electricMagenta,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InteractiveButton(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.electricMagenta,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Save',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (state is ThumbnailErrorState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.message),
          ],
        ),
      );
    }

    return const Center(
      child: Text('Unknown state'),
    );
  }

  Widget _buildUploadPlaceholder(BuildContext context, VoidCallback onUploadTap) {
    return InteractiveButton(
      onTap: onUploadTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.electricMagenta.withOpacity(0.6),
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
              color: AppColors.electricMagenta.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload Custom',
              style: TextStyle(
                color: AppColors.electricMagenta.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

}