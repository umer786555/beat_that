import 'dart:async';
import 'dart:io';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

part 'edit_uploaded_video_event.dart';
part 'edit_uploaded_video_state.dart';

class EditUploadedVideoBloc
    extends Bloc<EditUploadedVideoEvent, EditUploadedVideoState> {
  final supabaseService = locator<SupabaseService>();
  VideoPlayerController? _videoController;
  final String videoPath;

  EditUploadedVideoBloc({required this.videoPath})
    : super(EditUploadedVideoInitial()) {
    on<InitializeVideoEvent>(_onInitializeVideo);
    on<PlayVideoEvent>(_onPlayVideo);
    on<PauseVideoEvent>(_onPauseVideo);
    on<SeekVideoEvent>(_onSeekVideo);
    on<DisposeVideoEvent>(_onDisposeVideo);
  }

  /// Initialize video player with the given video path
  Future<void> _onInitializeVideo(
    InitializeVideoEvent event,
    Emitter<EditUploadedVideoState> emit,
  ) async {
    try {
      emit(EditUploadedVideoLoading());

      // Dispose old controller if exists
      await _videoController?.dispose();

      // Create new controller with file path
      _videoController = VideoPlayerController.file(File(event.videoPath));

      // Initialize the controller
      await _videoController!.initialize();

      // Emit initial ready state - only once
      emit(
        EditUploadedVideoReady(
          duration: _videoController!.value.duration,
          currentPosition: Duration.zero,
          isPlaying: false,
        ),
      );
    } catch (e) {
      emit(EditUploadedVideoError('Failed to initialize video: $e'));
    }
  }

  /// Play video
  Future<void> _onPlayVideo(
    PlayVideoEvent event,
    Emitter<EditUploadedVideoState> emit,
  ) async {
    if (_videoController == null) return;

    try {
      await _videoController!.play();

      emit(
        EditUploadedVideoPlaying(
          duration: _videoController!.value.duration,
          currentPosition: _videoController!.value.position,
        ),
      );
    } catch (e) {
      emit(EditUploadedVideoError('Failed to play video: $e'));
    }
  }

  /// Pause video
  Future<void> _onPauseVideo(
    PauseVideoEvent event,
    Emitter<EditUploadedVideoState> emit,
  ) async {
    if (_videoController == null) return;

    try {
      await _videoController!.pause();

      emit(
        EditUploadedVideoPaused(
          duration: _videoController!.value.duration,
          currentPosition: _videoController!.value.position,
        ),
      );
    } catch (e) {
      emit(EditUploadedVideoError('Failed to pause video: $e'));
    }
  }

  /// Seek to a specific position
  Future<void> _onSeekVideo(
    SeekVideoEvent event,
    Emitter<EditUploadedVideoState> emit,
  ) async {
    if (_videoController == null) return;

    try {
      await _videoController!.seekTo(event.position);

      final currentState = state;
      if (currentState is EditUploadedVideoPlaying) {
        emit(
          EditUploadedVideoPlaying(
            duration: _videoController!.value.duration,
            currentPosition: event.position,
          ),
        );
      } else if (currentState is EditUploadedVideoPaused) {
        emit(
          EditUploadedVideoPaused(
            duration: _videoController!.value.duration,
            currentPosition: event.position,
          ),
        );
      }
    } catch (e) {
      emit(EditUploadedVideoError('Failed to seek video: $e'));
    }
  }

  /// Dispose video controller
  Future<void> _onDisposeVideo(
    DisposeVideoEvent event,
    Emitter<EditUploadedVideoState> emit,
  ) async {
    await _videoController?.dispose();
    _videoController = null;
  }

  /// Get the video controller (for use in the UI)
  VideoPlayerController? get videoController => _videoController;
}
