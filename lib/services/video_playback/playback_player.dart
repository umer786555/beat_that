import 'package:beat_that/models/playback_progress.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Thin seam over the native player so pool and bloc logic run in `flutter test`.
///
/// Not fully player-agnostic: [videoController] exposes media_kit_video's
/// `VideoController` so widgets can render `Video`. The seam exists for
/// testability, not to make the player swappable.
abstract interface class PlaybackPlayer {
  /// Loads [source] into this player, replacing whatever was loaded before.
  ///
  /// [loop] maps to `PlaylistMode.single` / `PlaylistMode.none`.
  Future<void> open(String source, {required bool play, required bool loop});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Unloads the media and frees the decoder, but keeps the instance usable.
  Future<void> stop();

  Future<void> dispose();

  /// Combines position, duration and play state.
  Stream<PlaybackProgress> get progress;

  /// Video width; a value greater than 0 after an `open()` means the first
  /// frame is decoded.
  Stream<int?> get width;

  Stream<String> get error;

  /// Null in tests; widgets fall back to the thumbnail.
  VideoController? get videoController;
}
