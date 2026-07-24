import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/models/sport.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io';

part 'edit_thumbnail_event.dart';
part 'edit_thumbnail_state.dart';
part 'edit_thumbnail_presentation_event.dart';

class EditThumbnailBloc extends Bloc<EditThumbnailEvent, EditThumbnailState>
    with BlocPresentationMixin<EditThumbnailState, EditThumbnailPresentationEvent> {
  final videoPickerService = locator<VideoPickerService>();
  final supabaseService = locator<SupabaseService>();
  final PreferencesService preferencesService = locator<PreferencesService>();


  static const int _numberOfThumbnails = 6;
  static const int _thumbnailWidth = 512;
  static const int _thumbnailHeight = 512;
  static const int _imageQuality = 100;
  static const Duration _minimumUploadDuration = Duration(seconds: 10);

  final String videoPath;
  final Duration videoDuration;
  final Sport sport;
  final String? selectedSubcategory;
  Uint8List? selectedThumbnail;

  EditThumbnailBloc({
    required this.videoPath,
    required this.videoDuration,
    required this.sport,
    this.selectedSubcategory,
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
    try {

      // Emit loading state with placeholder thumbnails to show shimmer
      emit(
        ThumbnailsGeneratedState(
          thumbnails: List.filled(_numberOfThumbnails, Uint8List(0)),
          isLoading: true,
        ),
      );

      final int durationMilliseconds = videoDuration.inMilliseconds;
      final random = Random();

      final timeIntervals = List.generate(
        _numberOfThumbnails,
        (_) => random.nextInt(durationMilliseconds),
      )..sort(); // Sort for better UX (chronological order)

      // Wait for all thumbnails to be generated in parallel
      final thumbnails = await Future.wait(
        timeIntervals.map(
          (timeMilliseconds) => _generateThumbnail(timeMilliseconds),
        ),
      );

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

  Future<Uint8List?> _generateThumbnail(int timeMilliseconds) {
    return VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.PNG,
      maxWidth: _thumbnailWidth,
      maxHeight: _thumbnailHeight,
      timeMs: timeMilliseconds,
      quality: _imageQuality,
    );
  }

  Future<void> _onCustomThumbnailSelected(
    CustomThumbnailSelectedEvent event,
    Emitter<EditThumbnailState> emit,
  ) async {
    try {
      final selectedPhoto = await videoPickerService.pickGalleryPhoto();

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
              selectedIndex: updatedThumbnails.length - 1, // Select the new thumbnail
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
    try {
      if (videoDuration < _minimumUploadDuration) {
        emitPresentation(
          VideoTooShortEvent(
            message: 'Video must be at least 10 seconds long.',
          ),
        );
        return;
      }

      if (selectedThumbnail == null) {
        emitPresentation(
          ThumbnailErrorEvent(message: 'No thumbnail selected'),
        );
        return;
      }

      // Emit saving state
      emit(SavingVideoState(message: 'Preparing upload...'));

      // Convert video path (String) to File
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        emitPresentation(
          ThumbnailErrorEvent(message: 'Video file not found'),
        );
        return;
      }

      // Convert thumbnail bytes to temporary File
      final tempDir = await Directory.systemTemp.createTemp();
      final thumbnailFile = File('${tempDir.path}/thumbnail.png');
      await thumbnailFile.writeAsBytes(selectedThumbnail!);

      // Call Supabase service to upload video and thumbnail WITH PROGRESS TRACKING
      final result = await supabaseService.uploadVideoWithThumbnail(
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
        title: event.title,
        description: '', // Optional: add description if available
        sportId: sport.id,
        subcategoryId: selectedSubcategory != null && selectedSubcategory!.isNotEmpty
            ? sport.subcategories
                .firstWhere(
                  (sub) => sub.name == selectedSubcategory,
                  orElse: () => throw Exception('Subcategory not found: $selectedSubcategory'),
                )
                .id
            : null,
        subcategoryName: selectedSubcategory,
        // Progress callback for video upload
        onVideoProgress: (sent, total) {
          final progressPercent = (sent / total * 100).toStringAsFixed(0);
          print('📹 Video upload progress: $progressPercent% ($sent/$total bytes)');
          
          // Emit progress state for UI
          emit(VideoUploadProgressState(
            sentBytes: sent,
            totalBytes: total,
            progressPercent: int.parse(progressPercent),
          ));
        },
      );

      // Clean up temporary file
      await thumbnailFile.delete();

      if (result['success'] as bool) {
        // Get video ID from upload result
        final videoId = result['videoId'];

        // If a subcategory was selected, link the video to it
        if (selectedSubcategory != null && selectedSubcategory!.isNotEmpty) {
          // Find the subcategory ID from the selected subcategory name
          final subcategory = sport.subcategories.firstWhere(
            (sub) => sub.name == selectedSubcategory,
            orElse: () => throw Exception('Subcategory not found: $selectedSubcategory'),
          );

          final linkResult = await supabaseService.linkVideoToSubcategory(
            videoId: videoId,
            sportId: sport.id,
            subcategoryId: subcategory.id.toString(), // Convert subcategory ID to string
          );

          if (!linkResult['success']) {
            emitPresentation(
              ThumbnailErrorEvent(
                message: 'Upload succeeded but linking failed: ${linkResult['error']}',
              ),
            );
            return;
          }
        }

        // Reset to initial state to hide overlay
        emit(
          ThumbnailsGeneratedState(
            thumbnails: const [],
            isLoading: false,
          ),
        );
        
        // Emit success presentation event - UI will show snack bar and pop
        String message = 'Video uploaded successfully!\nTitle: ${event.title}';
        if (selectedSubcategory != null) {
          message += '\nLinked to: $selectedSubcategory';
        }
        
        emitPresentation(
          SaveSuccessEvent(message: message),
        );
      } else {
        emitPresentation(
          ThumbnailErrorEvent(
            message: 'Upload failed: ${result['message']}',
          ),
        );
      }
    } catch (e) {
      emitPresentation(
        ThumbnailErrorEvent(message: 'Failed to save: $e'),
      );
    }
  }

}