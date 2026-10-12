import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/constants/upload_limits.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/models/category.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:math';
import 'dart:io';

part 'edit_thumbnail_event.dart';
part 'edit_thumbnail_state.dart';
part 'edit_thumbnail_presentation_event.dart';

class EditThumbnailBloc extends Bloc<EditThumbnailEvent, EditThumbnailState>
    with
        BlocPresentationMixin<
          EditThumbnailState,
          EditThumbnailPresentationEvent
        > {
  final videoPickerService = locator<VideoPickerService>();
  final supabaseService = locator<SupabaseService>();
  final PreferencesService preferencesService = locator<PreferencesService>();

  static const int _numberOfThumbnails = 5;

  static const int _frameJpegQuality = 90;
  static const double _frameEdgeTrimFraction = 0.05;
  static const double _customPhotoMaxDimension = 1920;
  static const int _customPhotoQuality = 90;
  static const int _thumbnailBatchSize = 2;

  final String videoPath;
  final Duration videoDuration;
  final CategoryModel sport;
  final String? selectedSubcategory;
  final String? customSportName;
  Uint8List? selectedThumbnail;

  EditThumbnailBloc({
    required this.videoPath,
    required this.videoDuration,
    required this.sport,
    this.selectedSubcategory,
    this.customSportName,
  }) : super(EditThumbnailInitial()) {
    on<InitialEvent>(_onInitialEvent);
    on<ThumbnailSelectedEvent>(_onThumbnailSelected);
    on<CustomThumbnailSelectedEvent>(_onCustomThumbnailSelected);
    on<SaveEvent>(_onSaveEvent);
  }

  Future<void> _onInitialEvent(
    InitialEvent event,
    Emitter<EditThumbnailState> emit,
  ) async {
    // The Edit Video screen blocks this; guards restored routes.
    if (videoDuration < UploadLimits.minimumVideoDuration) {
      emitPresentation(VideoTooShortEvent(message: AppStrings.videoTooShort));
      return;
    }

    try {
      // Emit loading state with placeholder thumbnails to show shimmer
      emit(
        ThumbnailsGeneratedState(
          thumbnails: List.filled(_numberOfThumbnails, Uint8List(0)),
          isLoading: true,
        ),
      );

      final timeIntervals = frameTimestamps(videoDuration.inMilliseconds);

      final thumbnails = <Uint8List?>[];
      for (
        var startIndex = 0;
        startIndex < timeIntervals.length;
        startIndex += _thumbnailBatchSize
      ) {
        final endIndex = min(
          startIndex + _thumbnailBatchSize,
          timeIntervals.length,
        );
        final batch = timeIntervals.sublist(startIndex, endIndex);
        final batchThumbnails = await Future.wait(
          batch.map(_generateThumbnail),
        );
        thumbnails.addAll(batchThumbnails);
      }

      // Filter out any null values
      final nonNullThumbnails = thumbnails.whereType<Uint8List>().toList();

      if (nonNullThumbnails.isEmpty) {
        throw Exception('Failed to generate thumbnails');
      }

      // Set the first thumbnail as selected by default
      selectedThumbnail = nonNullThumbnails.first;
      emit(
        ThumbnailsGeneratedState(
          thumbnails: nonNullThumbnails,
          isLoading: false,
          selectedIndex: 0,
        ),
      );
    } catch (e) {
      emitPresentation(
        ThumbnailErrorEvent(message: 'Failed to generate thumbnails: $e'),
      );
    }
  }

  void _onThumbnailSelected(
    ThumbnailSelectedEvent event,
    Emitter<EditThumbnailState> emit,
  ) {
    final currentState = state;
    if (currentState is ThumbnailsGeneratedState) {
      selectedThumbnail = currentState.thumbnails[event.selectedIndex];
      emit(currentState.copyWith(selectedIndex: event.selectedIndex));
    }
  }

  // Skips the first/last 5%, where fades and black frames are common.
  @visibleForTesting
  static List<int> frameTimestamps(int durationMilliseconds, {Random? random}) {
    final rng = random ?? Random();
    final start = durationMilliseconds * _frameEdgeTrimFraction;
    final segment =
        durationMilliseconds *
        (1 - 2 * _frameEdgeTrimFraction) /
        _numberOfThumbnails;
    return List.generate(
      _numberOfThumbnails,
      (i) => (start + segment * (i + 0.25 + rng.nextDouble() * 0.5)).round(),
    );
  }

  // Full-res on purpose: upload downscales; passing both max dims distorts on Android.
  Future<Uint8List?> _generateThumbnail(int timeMilliseconds) {
    return VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: timeMilliseconds,
      quality: _frameJpegQuality,
    );
  }

  Future<void> _onCustomThumbnailSelected(
    CustomThumbnailSelectedEvent event,
    Emitter<EditThumbnailState> emit,
  ) async {
    try {
      final selectedPhoto = await videoPickerService.pickGalleryPhoto(
        maxDimension: _customPhotoMaxDimension,
        imageQuality: _customPhotoQuality,
      );

      if (selectedPhoto != null) {
        final currentState = state;
        if (currentState is ThumbnailsGeneratedState) {
          // Read the image file as bytes
          final imageBytes = await selectedPhoto.readAsBytes();

          // Add the new image to the existing thumbnails
          final updatedThumbnails = [...currentState.thumbnails, imageBytes];

          // Update selected thumbnail to the newly added one
          selectedThumbnail = imageBytes;

          // Emit the updated state with the new thumbnail added
          emit(
            currentState.copyWith(
              thumbnails: updatedThumbnails,
              selectedIndex:
                  updatedThumbnails.length - 1, // Select the new thumbnail
            ),
          );
        }
      }
    } catch (e) {
      emitPresentation(
        ThumbnailErrorEvent(message: 'Failed to add custom thumbnail: $e'),
      );
    }
  }

  Future<void> _onSaveEvent(
    SaveEvent event,
    Emitter<EditThumbnailState> emit,
  ) async {
    print('SaveEvent triggered with title: ${event.title}');
    print('Selected subcategory: $selectedSubcategory');
    print('sport: ${sport.displayName} (ID: ${sport.id})');
    Directory? thumbnailTempDir;
    try {
      if (selectedThumbnail == null) {
        emitPresentation(ThumbnailErrorEvent(message: 'No thumbnail selected'));
        return;
      }

      final categoryKey = sport.name.trim();
      if (categoryKey.isEmpty) {
        emitPresentation(
          ThumbnailErrorEvent(
            message: 'Unable to save video: category name is missing.',
          ),
        );
        return;
      }

      // Emit saving state
      emit(SavingVideoState(message: 'Preparing upload...'));

      // Convert video path (String) to File
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        emitPresentation(ThumbnailErrorEvent(message: 'Video file not found'));
        return;
      }

      // Extension must match the bytes: the uploader derives MIME type from it.
      final thumbnailBytes = selectedThumbnail!;
      final thumbnailExtension = switch (lookupMimeType(
        '',
        headerBytes: thumbnailBytes,
      )) {
        'image/png' => 'png',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        'image/heic' => 'heic',
        _ => 'jpg',
      };
      thumbnailTempDir = await Directory.systemTemp.createTemp('thumbnail_');
      final thumbnailFile = File(
        p.join(thumbnailTempDir.path, 'thumbnail.$thumbnailExtension'),
      );
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      // Call Supabase service to upload video and thumbnail WITH PROGRESS TRACKING
      final result = await supabaseService.uploadVideoWithThumbnail(
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
        title: event.title,
        description: '', // Optional: add description if available
        sportId: categoryKey,
        subcategoryId:
            selectedSubcategory != null && selectedSubcategory!.isNotEmpty
            ? sport.subcategories
                  .firstWhere(
                    (sub) => sub.name == selectedSubcategory,
                    orElse: () => throw Exception(
                      'Subcategory not found: $selectedSubcategory',
                    ),
                  )
                  .id
            : null,
        subcategoryName: selectedSubcategory,
        customOptionName: customSportName,
        // Progress callback for video upload
        onVideoProgress: (sent, total) {
          final progressPercent = (sent / total * 100).toStringAsFixed(0);
          print(
            '📹 Video upload progress: $progressPercent% ($sent/$total bytes)',
          );

          // Emit progress state for UI
          emit(
            VideoUploadProgressState(
              sentBytes: sent,
              totalBytes: total,
              progressPercent: int.parse(progressPercent),
            ),
          );
        },
      );

      if (result['success'] as bool) {
        // Reset to initial state to hide overlay
        emit(ThumbnailsGeneratedState(thumbnails: const [], isLoading: false));

        // Emit success presentation event - UI will show snack bar and pop
        // String message = 'Video uploaded successfully!\nTitle: ${event.title}';
        // if (selectedSubcategory != null && selectedSubcategory!.isNotEmpty) {
        //   message += '\nSaved for: $selectedSubcategory';
        // }

        emitPresentation(
          SaveSuccessEvent(message: 'Video uploaded successfully!'),
        );
      } else {
        emitPresentation(
          ThumbnailErrorEvent(message: 'Upload failed: ${result['message']}'),
        );
      }
    } catch (e) {
      emitPresentation(ThumbnailErrorEvent(message: 'Failed to save: $e'));
    } finally {
      try {
        await thumbnailTempDir?.delete(recursive: true);
      } on FileSystemException catch (e) {
        print('Failed to delete thumbnail temp dir: $e');
      }
    }
  }
}
