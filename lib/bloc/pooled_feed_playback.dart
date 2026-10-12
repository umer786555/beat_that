import 'dart:async';

import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/video_engagement_tracker.dart';
import 'package:beat_that/services/video_playback/video_player_pool.dart';
import 'package:beat_that/services/video_playback/video_slot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pool playback and view counting shared by the vertical video feeds.
///
/// Call [startPlayback] from `initialize`, [activatePlayback] whenever the
/// current video changes, and [stopPlayback] from `close`.
mixin PooledFeedPlayback<S> on Cubit<S> {
  static const Duration _viewCountThreshold = Duration(seconds: 8);
  static const Duration _replayResetThreshold = Duration(milliseconds: 600);

  final VideoPlayerPool _pool = locator<VideoPlayerPool>();
  StreamSubscription<PlaybackProgress>? _progressSubscription;
  bool _viewThresholdReached = false;

  @protected
  late final VideoEngagementTracker engagementTracker = VideoEngagementTracker(
    locator<PreferencesService>(),
  );

  @protected
  List<SportVideo> get feedVideos;

  @protected
  int get feedCurrentIndex;

  /// The active video has played past the view threshold.
  @protected
  void onViewThresholdReached();

  ValueListenable<VideoSlot> slotFor(int index) =>
      _pool.slotFor(feedVideos[index].videoPath);

  void togglePlayback(int index) {
    if (index != feedCurrentIndex) {
      return;
    }

    _pool.toggleActivePlayback(this);
  }

  void onRouteCovered() => _pool.addPauseReason(PauseReason.covered);

  void onRouteUncovered() => _pool.removePauseReason(PauseReason.covered);

  void onAdShown() => _pool.addPauseReason(PauseReason.ad);

  void onAdClosed() => _pool.removePauseReason(PauseReason.ad);

  @protected
  void startPlayback() {
    _pool.claim(this);
    _progressSubscription = _pool.activeProgress.listen(_onProgress);
  }

  /// Restarts view counting for the current video and moves the window to it.
  @protected
  void activatePlayback() {
    _viewThresholdReached = false;
    updatePlaybackWindow();
  }

  /// Points the pool's preload window at the current video. Synchronous, so a
  /// fast fling just supersedes the previous window.
  @protected
  void updatePlaybackWindow() {
    _pool.setWindow(
      owner: this,
      keys: [for (final video in feedVideos) video.videoPath],
      activeIndex: feedCurrentIndex,
    );
  }

  @protected
  void retryPlayback(String videoPath) => _pool.retry(this, videoPath);

  @protected
  Future<void> stopPlayback() async {
    _pool.release(this);
    await _progressSubscription?.cancel();
    engagementTracker.stop();
  }

  /// Driven only by the pool's active player, so preloads never count a view.
  void _onProgress(PlaybackProgress progress) {
    engagementTracker.onPlaybackProgress(progress);

    if (progress.position <= _replayResetThreshold) {
      _viewThresholdReached = false;
    }

    if (!progress.isPlaying ||
        _viewThresholdReached ||
        progress.position < _viewCountThreshold) {
      return;
    }

    _viewThresholdReached = true;
    onViewThresholdReached();
  }
}
