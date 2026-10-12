import 'dart:async';

import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/services/video_playback/playback_player.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Production [PlaybackPlayer] backed by a media_kit (libmpv) [Player].
///
/// Keeps media_kit's default `hwdec` so iOS uses VideoToolbox and Android
/// uses MediaCodec.
class MediaKitPlaybackPlayer implements PlaybackPlayer {
  MediaKitPlaybackPlayer()
    : _player = Player(
        // 8 MiB instead of the 32 MiB default: the pool keeps up to five
        // players loaded at once.
        configuration: const PlayerConfiguration(bufferSize: 8 * 1024 * 1024),
      ) {
    _controller = VideoController(_player);
    _subscriptions.addAll([
      _player.stream.position.listen(
        (position) => _emitProgress(_progress.copyWith(position: position)),
      ),
      _player.stream.duration.listen(
        (duration) => _emitProgress(_progress.copyWith(duration: duration)),
      ),
      _player.stream.playing.listen(
        (playing) => _emitProgress(_progress.copyWith(isPlaying: playing)),
      ),
      if (kDebugMode) _player.stream.width.listen(_logHardwareDecoder),
    ]);
  }

  final Player _player;
  late final VideoController _controller;
  final _progressController = StreamController<PlaybackProgress>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  PlaybackProgress _progress = PlaybackProgress.zero;
  bool _isDisposed = false;

  @override
  Stream<PlaybackProgress> get progress => _progressController.stream;

  @override
  Stream<int?> get width => _player.stream.width;

  @override
  Stream<String> get error => _player.stream.error;

  @override
  VideoController get videoController => _controller;

  @override
  Future<void> open(
    String source, {
    required bool play,
    required bool loop,
  }) async {
    await _player.setPlaylistMode(
      loop ? PlaylistMode.single : PlaylistMode.none,
    );
    await _player.open(Media(source), play: play);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    // media_kit asserts on a second dispose.
    if (_isDisposed) return;
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _progressController.close();
    await _player.dispose();
  }

  void _emitProgress(PlaybackProgress progress) {
    _progress = progress;
    if (!_progressController.isClosed) _progressController.add(progress);
  }

  /// Lets the profiling checklist confirm hardware decoding per platform.
  Future<void> _logHardwareDecoder(int? width) async {
    if (width == null || width <= 0) return;
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    final hwdec = await platform.getProperty('hwdec-current');
    debugPrint('MediaKitPlaybackPlayer hwdec-current: $hwdec');
  }
}
