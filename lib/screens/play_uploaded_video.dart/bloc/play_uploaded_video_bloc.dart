import 'dart:async';
import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/video_playback/playback_player.dart';
import 'package:beat_that/services/video_playback/video_source_resolver.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'play_uploaded_video_event.dart';
part 'play_uploaded_video_state.dart';

class PlayUploadedVideoBloc
    extends Bloc<PlayUploadedVideoEvent, PlayUploadedVideoState> {
  PlaybackPlayer? _player;
  StreamSubscription<PlaybackProgress>? _progressSubscription;
  PlaybackProgress _progress = PlaybackProgress.zero;
  final String videoPath;
  final VideoSourceResolver _sourceResolver = locator<VideoSourceResolver>();

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

      // Replace the player synchronously so close() always disposes the
      // latest one, even if it runs while this handler is still awaiting.
      final previousPlayer = _player;
      final player = _player = locator<PlaybackPlayer>();
      await _progressSubscription?.cancel();
      _progress = PlaybackProgress.zero;
      _progressSubscription = player.progress.listen((p) => _progress = p);
      await previousPlayer?.dispose();

      final source = await _sourceResolver.resolve(videoPath);

      // Subscribe before open() so neither event is missed.
      final loadedOrFailed = Future.any<Object>([
        player.progress.firstWhere((p) => p.duration > Duration.zero),
        player.error.first,
      ]);
      try {
        await player.open(source, play: false, loop: false);
      } catch (_) {
        // Nothing will await it now, and it fails once the player is disposed.
        loadedOrFailed.ignore();
        rethrow;
      }
      final outcome = await loadedOrFailed;
      if (outcome is! PlaybackProgress) throw Exception(outcome);

      // Emit initial ready state - only once
      emit(
        PlayUploadedVideoReady(
          duration: outcome.duration,
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
    if (_player == null) return;

    try {
      await _player!.play();

      emit(
        PlayUploadedVideoPlaying(
          duration: _progress.duration,
          currentPosition: _progress.position,
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
    if (_player == null) return;

    try {
      await _player!.pause();

      emit(
        PlayUploadedVideoPaused(
          duration: _progress.duration,
          currentPosition: _progress.position,
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
    if (_player == null) return;

    try {
      await _player!.seek(event.position);

      final currentState = state;
      if (currentState is PlayUploadedVideoPlaying) {
        emit(
          PlayUploadedVideoPlaying(
            duration: _progress.duration,
            currentPosition: event.position,
          ),
        );
      } else if (currentState is PlayUploadedVideoPaused) {
        emit(
          PlayUploadedVideoPaused(
            duration: _progress.duration,
            currentPosition: event.position,
          ),
        );
      }
    } catch (e) {
      emit(PlayUploadedVideoError('Failed to seek video: $e'));
    }
  }

  /// Dispose the player; safe to call more than once.
  Future<void> _onDisposeVideo(
    DisposeVideoEvent event,
    Emitter<PlayUploadedVideoState> emit,
  ) => _disposePlayer();

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    await _progressSubscription?.cancel();
    _progressSubscription = null;
    await player?.dispose();
  }

  @override
  Future<void> close() async {
    await super.close();
    await _disposePlayer();
  }

  /// Get the player (for use in the UI)
  PlaybackPlayer? get player => _player;

  /// Latest progress of [player], to seed widgets that listen to its stream.
  PlaybackProgress get progress => _progress;
}
