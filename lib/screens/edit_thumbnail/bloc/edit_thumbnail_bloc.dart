import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'dart:math';

part 'edit_thumbnail_event.dart';
part 'edit_thumbnail_state.dart';

class EditThumbnailBloc extends Bloc<EditThumbnailEvent, EditThumbnailState> {
  static const int _numberOfThumbnails = 6;
  static const int _thumbnailWidth = 512;
  static const int _thumbnailHeight = 512;
  static const int _imageQuality = 100;

  final String videoPath;
  final Duration videoDuration;

  EditThumbnailBloc({required this.videoPath, required this.videoDuration}) : super(EditThumbnailInitial()) {
    on<InitialEvent>(_onInitialEvent);
    on<ThumbnailSelectedEvent>(_onThumbnailSelected);
  }

  Future<void> _onInitialEvent(
    InitialEvent event,
    Emitter<EditThumbnailState> emit,
  ) async {
    try {
      // Emit loading state with placeholder thumbnails to show shimmer
      emit(ThumbnailsGeneratedState(
        thumbnails: List.filled(_numberOfThumbnails, Uint8List(0)),
        isLoading: true,
      ));
      
      final int durationMilliseconds = videoDuration.inMilliseconds;
      final random = Random();
      
      final timeIntervals = List.generate(
        _numberOfThumbnails,
        (_) => random.nextInt(durationMilliseconds),
      )..sort(); // Sort for better UX (chronological order)
      
      // Wait for all thumbnails to be generated in parallel
      final thumbnails = await Future.wait(
        timeIntervals.map((timeMilliseconds) => _generateThumbnail(timeMilliseconds))
      );
      
      // Filter out any null values
      final nonNullThumbnails = thumbnails.whereType<Uint8List>().toList();
      
      if (nonNullThumbnails.isEmpty) {
        throw Exception('Failed to generate thumbnails');
      }
      
      emit(ThumbnailsGeneratedState(thumbnails: nonNullThumbnails, isLoading: false));
    } catch (e) {
      emit(ThumbnailErrorState(message: 'Failed to generate thumbnails: $e'));
    }
  }

  void _onThumbnailSelected(
    ThumbnailSelectedEvent event,
    Emitter<EditThumbnailState> emit,
  ) {
    final currentState = state;
    if (currentState is ThumbnailsGeneratedState) {
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
}
