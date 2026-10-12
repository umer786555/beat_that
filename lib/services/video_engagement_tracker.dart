import 'dart:async';

import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/services/preferences_service.dart';

/// Turns how a viewer reacts to the active video into interest signals.
///
/// Each signal is recorded at most once per viewing, so a looping video
/// can't inflate its subcategory.
class VideoEngagementTracker {
  VideoEngagementTracker(this._preferences);

  static const Duration watchedThreshold = Duration(seconds: 8);
  static const Duration quickSkipThreshold = Duration(seconds: 2);
  static const double _completionFraction = 0.9;
  static const int _highRatingMin = 8;
  static const int _lowRatingMax = 4;

  final PreferencesService _preferences;

  int? _subcategoryId;
  Duration _lastPosition = Duration.zero;
  Duration _furthestPosition = Duration.zero;
  bool _hasPlayed = false;
  bool _watchedRecorded = false;
  bool _completedRecorded = false;
  bool _ratingRecorded = false;

  /// Closes out the previous video (a swipe away) and starts tracking a new one.
  void startVideo(int? subcategoryId) {
    _finishCurrentVideo();
    _subcategoryId = subcategoryId;
    _lastPosition = Duration.zero;
    _furthestPosition = Duration.zero;
    _hasPlayed = false;
    _watchedRecorded = false;
    _completedRecorded = false;
    _ratingRecorded = false;
  }

  void onPlaybackProgress(PlaybackProgress progress) {
    if (_subcategoryId == null) return;

    final position = progress.position;
    final duration = progress.duration;
    if (progress.isPlaying) _hasPlayed = true;
    if (position > _furthestPosition) _furthestPosition = position;

    if (!_watchedRecorded && position >= watchedThreshold) {
      _watchedRecorded = true;
      _record(EngagementSignal.watched);
    }

    // Position is polled, so detect the loop as a jump from the end back to the first half.
    if (!_completedRecorded &&
        duration > Duration.zero &&
        _lastPosition >= duration * _completionFraction &&
        position <= duration * 0.5) {
      _completedRecorded = true;
      _record(EngagementSignal.completed);
    }

    _lastPosition = position;
  }

  void onRated(int rating) {
    if (_ratingRecorded) return;

    if (rating >= _highRatingMin) {
      _ratingRecorded = true;
      _record(EngagementSignal.ratedHigh);
    } else if (rating <= _lowRatingMax) {
      _ratingRecorded = true;
      _record(EngagementSignal.ratedLow);
    }
  }

  /// Leaving the feed isn't a skip: the viewer chose this video from the grid.
  void stop() {
    _subcategoryId = null;
  }

  void _finishCurrentVideo() {
    if (_hasPlayed &&
        !_watchedRecorded &&
        !_completedRecorded &&
        _furthestPosition < quickSkipThreshold) {
      _record(EngagementSignal.quickSkip);
    }
  }

  void _record(EngagementSignal signal) {
    final subcategoryId = _subcategoryId;
    if (subcategoryId == null) return;
    unawaited(_preferences.recordEngagement(subcategoryId, signal));
  }
}
