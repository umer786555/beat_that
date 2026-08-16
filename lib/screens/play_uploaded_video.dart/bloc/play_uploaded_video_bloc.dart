import 'dart:async';
import 'dart:io';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

part 'play_uploaded_video_event.dart';
part 'play_uploaded_video_state.dart';

class PlayUploadedVideoBloc
    extends Bloc<PlayUploadedVideoEvent, PlayUploadedVideoState> {
  VideoPlayerController? _videoController;
  final String videoPath;
  final SupabaseService _supabaseService = locator<SupabaseService>();

  PlayUploadedVideoBloc({required this.videoPath})
    : super(PlayUploadedVideoInitial()) {
    on<InitializeVideoEvent>(_onInitializeVideo);
    on<PlayVideoEvent>(_onPlayVideo);
    on<PauseVideoEvent>(_onPauseVideo);
    on<SeekVideoEvent>(_onSeekVideo);
    on<DisposeVideoEvent>(_onDisposeVideo);
  }

  /// Initialize video player with the given video path or URL
  /// Supports both local file paths and remote URLs from Supabase
  Future<void> _onInitializeVideo(
    InitializeVideoEvent event,
    Emitter<PlayUploadedVideoState> emit,
  ) async {
    try {
      emit(PlayUploadedVideoLoading());

      // Dispose old controller if exists
      await _videoController?.dispose();

      final isUrl =
          videoPath.startsWith('http://') ||
          videoPath.startsWith('https://');
      final localFile = File(videoPath);
      final isLocalFile = !isUrl && await localFile.exists();

      if (isUrl) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(videoPath),
        );
      } else if (isLocalFile) {
        _videoController = VideoPlayerController.file(localFile);
      } else {
        final resolvedVideoUrl = await _supabaseService.resolveVideoPlaybackUrl(
          videoPath,
        );
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(resolvedVideoUrl),
        );
      }

      // Initialize the controller
      await _videoController!.initialize();

      // Emit initial ready state - only once
      emit(
        PlayUploadedVideoReady(
          duration: _videoController!.value.duration,
          currentPosition: Duration.zero,
          isPlaying: false,
        ),
      );
    } catch (e) {
      emit(PlayUploadedVideoError('Failed to initialize video: $e'));
    }
  }

  /// Play video
  Future<void> _onPlayVideo(
    PlayVideoEvent event,
    Emitter<PlayUploadedVideoState> emit,
  ) async {
    if (_videoController == null) return;

    try {
      await _videoController!.play();

      emit(
        PlayUploadedVideoPlaying(
          duration: _videoController!.value.duration,
          currentPosition: _videoController!.value.position,
        ),
      );
    } catch (e) {
      emit(PlayUploadedVideoError('Failed to play video: $e'));
    }
  }

  /// Pause video
  Future<void> _onPauseVideo(
    PauseVideoEvent event,
    Emitter<PlayUploadedVideoState> emit,
  ) async {
    if (_videoController == null) return;

    try {
      await _videoController!.pause();

      emit(
        PlayUploadedVideoPaused(
          duration: _videoController!.value.duration,
          currentPosition: _videoController!.value.position,
        ),
      );
    } catch (e) {
      emit(PlayUploadedVideoError('Failed to pause video: $e'));
    }
  }

  /// Seek to a specific position
  Future<void> _onSeekVideo(
    SeekVideoEvent event,
    Emitter<PlayUploadedVideoState> emit,
  ) async {
    if (_videoController == null) return;

    try {
      await _videoController!.seekTo(event.position);

      final currentState = state;
      if (currentState is PlayUploadedVideoPlaying) {
        emit(
          PlayUploadedVideoPlaying(
            duration: _videoController!.value.duration,
            currentPosition: event.position,
          ),
        );
      } else if (currentState is PlayUploadedVideoPaused) {
        emit(
          PlayUploadedVideoPaused(
            duration: _videoController!.value.duration,
            currentPosition: event.position,
          ),
        );
      }
    } catch (e) {
      emit(PlayUploadedVideoError('Failed to seek video: $e'));
    }
  }

  /// Dispose video controller
  Future<void> _onDisposeVideo(
    DisposeVideoEvent event,
    Emitter<PlayUploadedVideoState> emit,
  ) async {
    await _videoController?.dispose();
    _videoController = null;
  }

  /// Get the video controller (for use in the UI)
  VideoPlayerController? get videoController => _videoController;
}
