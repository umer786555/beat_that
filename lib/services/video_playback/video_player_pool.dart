import 'dart:async';

import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/services/video_playback/playback_player.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter/foundation.dart';

/// Why playback is held, on top of the user's own pause.
enum PauseReason { background, covered, ad }

/// App-scoped pool of reusable players shared by the vertical video feeds.
///
/// Three choices here are deliberate; read these before "fixing" them:
///
/// * **Preloads stay paused on their first frame.** Only the active video
///   plays, so there is one active decoder, no audio from preloads and no view
///   or engagement signal from a video the viewer hasn't reached.
/// * **Players are never disposed.** Evicting a key loads a new source into
///   the least recently used player with `open()`, and [release] only `stop()`s
///   players. Disposing media_kit players crashes Android release builds
///   (media-kit#1443, #1348) and blocks the UI thread (#700).
/// * **"Ready" means width > 0 after the latest `open()`.** media_kit's
///   `waitUntilFirstFrameRendered` completes once per controller, so it can't
///   be reused. Ready only removes the thumbnail; playback starts as soon as
///   `open()` completes, so a platform that reports width late can't stall
///   the feed.
class VideoPlayerPool {
  VideoPlayerPool({
    required PlaybackPlayer Function() createPlayer,
    required Future<String> Function(String videoPath) resolveSource,
    this.size = 5,
  }) : assert(size > 0, 'The pool needs at least one player'),
       _createPlayer = createPlayer,
       _resolveSource = resolveSource;

  final int size;
  final PlaybackPlayer Function() _createPlayer;
  final Future<String> Function(String videoPath) _resolveSource;

  final List<_PooledPlayer> _players = [];
  final Map<String, _PooledPlayer> _bound = {};
  final Map<String, ValueNotifier<VideoSlot>> _slots = {};
  final Set<PauseReason> _reasons = {};
  final _activeProgress = StreamController<PlaybackProgress>.broadcast();

  Object? _owner;
  String? _activeKey;
  bool _userPaused = false;
  int _clock = 0;

  /// Progress of the active video only; preloads never appear here.
  Stream<PlaybackProgress> get activeProgress => _activeProgress.stream;

  /// The slot for [key]. Two pages with the same key share one slot.
  ValueListenable<VideoSlot> slotFor(String key) => _slot(key);

  /// Makes [owner] the feed that drives the pool, releasing any previous one.
  void claim(Object owner) {
    final previous = _owner;
    if (previous != null && !identical(previous, owner)) release(previous);
    _owner = owner;
  }

  /// Stops every player and forgets all keys, unless [owner] has already been
  /// replaced by a newer feed.
  void release(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _activeKey = null;
    _userPaused = false;
    _reasons
      ..remove(PauseReason.covered)
      ..remove(PauseReason.ad);
    for (final pooled in _players) {
      pooled.unbind();
      unawaited(pooled.player.stop());
    }
    _bound.clear();
    // Pages still mounted during an exit transition must not keep a controller
    // that the next owner is about to reuse.
    for (final slot in _slots.values) {
      slot.value = const VideoSlot.loading();
    }
    _slots.clear();
  }

  /// Loads the window around [activeIndex] and plays the active video.
  ///
  /// Synchronous so each call supersedes the last one during a fast fling.
  /// Ignored unless [owner] holds the pool, like the other feed-driven calls.
  void setWindow({
    required Object owner,
    required List<String> keys,
    required int activeIndex,
  }) {
    if (!_isOwner(owner)) return;

    final wanted = <String>[];
    for (final offset in const [0, 1, 2, -1]) {
      final index = activeIndex + offset;
      if (index < 0 || index >= keys.length) continue;
      final key = keys[index];
      if (key.isEmpty || wanted.contains(key)) continue;
      wanted.add(key);
    }
    if (wanted.length > size) wanted.removeRange(size, wanted.length);

    for (final key in wanted) {
      if (_bound.containsKey(key)) continue;
      final pooled = _takePlayer(wanted);
      _bind(pooled, key);
    }

    final activeKey =
        activeIndex >= 0 &&
            activeIndex < keys.length &&
            keys[activeIndex].isNotEmpty
        ? keys[activeIndex]
        : null;
    for (final key in wanted.where((key) => key != activeKey)) {
      _bound[key]!.lastUsed = ++_clock;
    }
    if (activeKey != null) _bound[activeKey]!.lastUsed = ++_clock;

    if (activeKey != _activeKey) {
      _activeKey = activeKey;
      _userPaused = false;
      final active = _bound[activeKey];
      if (active != null && active.progress.position > Duration.zero) {
        unawaited(active.player.seek(Duration.zero));
      }
    }
    _syncPlayback();
  }

  /// Pauses or resumes the active video at the user's request.
  void toggleActivePlayback(Object owner) {
    if (!_isOwner(owner)) return;
    _userPaused = !_userPaused;
    _syncPlayback();
  }

  /// Reopens [key] after an error without touching other slots.
  void retry(Object owner, String key) {
    if (!_isOwner(owner)) return;
    final pooled = _bound[key];
    if (pooled == null) return;
    _slot(key).value = const VideoSlot.loading();
    unawaited(_load(pooled, key));
  }

  void addPauseReason(PauseReason reason) {
    _reasons.add(reason);
    _syncPlayback();
  }

  void removePauseReason(PauseReason reason) {
    _reasons.remove(reason);
    _syncPlayback();
  }

  bool _isOwner(Object owner) => _owner != null && identical(owner, _owner);

  ValueNotifier<VideoSlot> _slot(String key) =>
      _slots.putIfAbsent(key, () => ValueNotifier(const VideoSlot.loading()));

  _PooledPlayer _takePlayer(List<String> wanted) {
    for (final pooled in _players) {
      if (pooled.key == null) return pooled;
    }
    if (_players.length < size) {
      final pooled = _PooledPlayer(_createPlayer());
      _players.add(pooled);
      _listen(pooled);
      return pooled;
    }
    return _players
        .where((pooled) => !wanted.contains(pooled.key))
        .reduce((a, b) => a.lastUsed <= b.lastUsed ? a : b);
  }

  void _bind(_PooledPlayer pooled, String key) {
    final evictedKey = pooled.key;
    if (evictedKey != null) {
      _bound.remove(evictedKey);
      // Before touching the player, so the evicted page shows its thumbnail
      // instead of the next source's frames.
      _slots[evictedKey]?.value = const VideoSlot.loading();
    }
    // Silence the old source now rather than when the new open() lands.
    if (pooled.isPlayRequested) unawaited(pooled.player.pause());
    pooled.unbind();
    pooled.key = key;
    _bound[key] = pooled;
    _slot(key).value = const VideoSlot.loading();
    unawaited(_load(pooled, key));
  }

  Future<void> _load(_PooledPlayer pooled, String key) async {
    final token = ++pooled.token;
    final owner = _owner;
    pooled
      ..isOpenStarted = false
      ..isOpened = false
      ..hasFrame = false
      ..isPlayRequested = false
      ..progress = PlaybackProgress.zero;
    bool isCurrent() => pooled.token == token && identical(_owner, owner);

    try {
      final source = await _resolveSource(key);
      if (!isCurrent()) return;
      pooled.isOpenStarted = true;
      await pooled.player.open(source, play: false, loop: true);
      if (!isCurrent()) {
        // Released while opening: don't leave media loaded in an idle player.
        if (pooled.key == null) unawaited(pooled.player.stop());
        return;
      }
      pooled.isOpened = true;
      _markReadyIfFramed(pooled);
      _syncPlayback();
    } catch (error) {
      if (!isCurrent()) return;
      debugPrint('VideoPlayerPool failed to open $key: $error');
      _slot(key).value = const VideoSlot(status: VideoSlotStatus.error);
    }
  }

  void _listen(_PooledPlayer pooled) {
    pooled.player.width.listen((width) {
      // open() resets width to null, so a later value belongs to the new source.
      pooled.hasFrame = width != null && width > 0;
      _markReadyIfFramed(pooled);
    });
    pooled.player.error.listen((message) {
      final key = pooled.key;
      // Before this load's open() starts, an error belongs to the previous
      // source. Once the video shows, mpv's decoder and stream logs aren't
      // fatal, so only an error while loading fails the slot.
      if (key == null || !pooled.isOpenStarted) return;
      final slot = _slot(key);
      if (slot.value.status != VideoSlotStatus.loading) return;
      debugPrint('VideoPlayerPool playback error for $key: $message');
      slot.value = const VideoSlot(status: VideoSlotStatus.error);
      // Stop the audio under the error overlay until a retry reopens it.
      pooled.isOpened = false;
      _syncPlayback();
    });
    pooled.player.progress.listen((progress) {
      final key = pooled.key;
      if (key == null || !pooled.isOpened) return;
      pooled.progress = progress;
      final slot = _slot(key);
      slot.value = slot.value.copyWith(isPlaying: progress.isPlaying);
      if (key == _activeKey) _activeProgress.add(progress);
    });
  }

  void _markReadyIfFramed(_PooledPlayer pooled) {
    final key = pooled.key;
    if (key == null || !pooled.isOpened || !pooled.hasFrame) return;
    final slot = _slot(key);
    if (slot.value.status != VideoSlotStatus.loading) return;
    slot.value = VideoSlot(
      status: VideoSlotStatus.ready,
      videoController: pooled.player.videoController,
      isPlaying: slot.value.isPlaying,
    );
  }

  /// Plays the active player when nothing holds playback; pauses the rest.
  void _syncPlayback() {
    final canPlay = _owner != null && _reasons.isEmpty && !_userPaused;
    for (final pooled in _players) {
      final shouldPlay =
          canPlay &&
          pooled.isOpened &&
          pooled.key != null &&
          pooled.key == _activeKey;
      if (shouldPlay == pooled.isPlayRequested) continue;
      pooled.isPlayRequested = shouldPlay;
      unawaited(shouldPlay ? pooled.player.play() : pooled.player.pause());
    }
  }
}

class _PooledPlayer {
  _PooledPlayer(this.player);

  final PlaybackPlayer player;
  String? key;

  /// Bumped on every load and unbind; async work for an older token is dropped.
  int token = 0;
  int lastUsed = 0;

  /// The current load has called `open()`, so errors belong to its source.
  bool isOpenStarted = false;
  bool isOpened = false;
  bool hasFrame = false;
  bool isPlayRequested = false;
  PlaybackProgress progress = PlaybackProgress.zero;

  void unbind() {
    key = null;
    token++;
    isOpenStarted = false;
    isOpened = false;
    hasFrame = false;
    isPlayRequested = false;
    progress = PlaybackProgress.zero;
  }
}
