import 'dart:async';

import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/services/video_playback/playback_player.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// In-memory [PlaybackPlayer] whose streams and `open()` the test controls.
///
/// Count instances through the factory closure rather than a static counter:
/// `createPlayer: () { final p = FakePlaybackPlayer(); created.add(p); return p; }`.
class FakePlaybackPlayer implements PlaybackPlayer {
  FakePlaybackPlayer({this.holdOpens = false});

  /// When true, `open()` waits until [completeOpens] or [failOpens] is called.
  bool holdOpens;

  final openCalls = <({String source, bool play, bool loop})>[];
  final seeks = <Duration>[];
  bool isPlaying = false;
  bool isLoaded = false;
  bool isDisposed = false;
  int stopCount = 0;

  final _progress = StreamController<PlaybackProgress>.broadcast();
  final _width = StreamController<int?>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _pendingOpens = <Completer<void>>[];

  List<String> get openedSources => [for (final call in openCalls) call.source];

  @override
  Stream<PlaybackProgress> get progress => _progress.stream;

  @override
  Stream<int?> get width => _width.stream;

  @override
  Stream<String> get error => _error.stream;

  @override
  VideoController? get videoController => null;

  @override
  Future<void> open(
    String source, {
    required bool play,
    required bool loop,
  }) async {
    openCalls.add((source: source, play: play, loop: loop));
    isLoaded = false;
    isPlaying = false;
    if (holdOpens) {
      final pending = Completer<void>();
      _pendingOpens.add(pending);
      await pending.future;
    }
    isLoaded = true;
    isPlaying = play;
  }

  void completeOpens() {
    for (final pending in _pendingOpens) {
      pending.complete();
    }
    _pendingOpens.clear();
  }

  void failOpens(Object error) {
    for (final pending in _pendingOpens) {
      pending.completeError(error);
    }
    _pendingOpens.clear();
  }

  @override
  Future<void> play() async {
    isPlaying = isLoaded;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    isLoaded = false;
    isPlaying = false;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    isLoaded = false;
    isPlaying = false;
    await _progress.close();
    await _width.close();
    await _error.close();
  }

  void emitProgress(PlaybackProgress progress) => _progress.add(progress);

  void emitWidth(int? width) => _width.add(width);

  void emitError(String message) => _error.add(message);
}
