import 'package:beat_that/models/playback_progress.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/video_engagement_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPreferencesService extends Mock implements PreferencesService {}

void main() {
  setUpAll(() {
    registerFallbackValue(EngagementSignal.watched);
  });

  late MockPreferencesService preferences;
  late VideoEngagementTracker tracker;

  PlaybackProgress playing(int seconds, {int durationSeconds = 20}) {
    return PlaybackProgress(
      duration: Duration(seconds: durationSeconds),
      position: Duration(seconds: seconds),
      isPlaying: true,
    );
  }

  setUp(() {
    preferences = MockPreferencesService();
    when(
      () => preferences.recordEngagement(any(), any()),
    ).thenAnswer((_) async {});
    tracker = VideoEngagementTracker(preferences);
  });

  test('records watched once after 8 seconds, even across loops', () {
    tracker.startVideo(5);

    tracker.onPlaybackProgress(playing(3));
    verifyNever(() => preferences.recordEngagement(any(), any()));

    tracker.onPlaybackProgress(playing(8));
    tracker.onPlaybackProgress(playing(12));
    tracker.onPlaybackProgress(playing(0));
    tracker.onPlaybackProgress(playing(9));

    verify(
      () => preferences.recordEngagement(5, EngagementSignal.watched),
    ).called(1);
  });

  test('records completed once when the video loops after finishing', () {
    tracker.startVideo(5);

    tracker.onPlaybackProgress(playing(19));
    tracker.onPlaybackProgress(playing(0));
    tracker.onPlaybackProgress(playing(19));
    tracker.onPlaybackProgress(playing(0));

    verify(
      () => preferences.recordEngagement(5, EngagementSignal.completed),
    ).called(1);
  });

  test('does not count the start of playback as a completion', () {
    tracker.startVideo(5);

    tracker.onPlaybackProgress(playing(0));
    tracker.onPlaybackProgress(playing(5));

    verifyNever(
      () => preferences.recordEngagement(any(), EngagementSignal.completed),
    );
  });

  test('detects a loop even when the first poll after it is late', () {
    tracker.startVideo(5);

    tracker.onPlaybackProgress(playing(19));
    tracker.onPlaybackProgress(
      const PlaybackProgress(
        duration: Duration(seconds: 20),
        position: Duration(milliseconds: 900),
        isPlaying: true,
      ),
    );

    verify(
      () => preferences.recordEngagement(5, EngagementSignal.completed),
    ).called(1);
  });

  test('small backwards jitter near the end is not a completion', () {
    tracker.startVideo(5);

    tracker.onPlaybackProgress(playing(19));
    tracker.onPlaybackProgress(playing(18));

    verifyNever(
      () => preferences.recordEngagement(any(), EngagementSignal.completed),
    );
  });

  test('a new viewing does not inherit the previous video position', () {
    tracker.startVideo(5);
    tracker.onPlaybackProgress(playing(19));

    tracker.startVideo(6);
    tracker.onPlaybackProgress(playing(0));

    verifyNever(
      () => preferences.recordEngagement(any(), EngagementSignal.completed),
    );
  });

  test('records a quick skip when swiping away within 2 seconds', () {
    tracker.startVideo(5);
    tracker.onPlaybackProgress(playing(1));

    tracker.startVideo(6);

    verify(
      () => preferences.recordEngagement(5, EngagementSignal.quickSkip),
    ).called(1);
  });

  test('does not penalise a video that never started playing', () {
    tracker.startVideo(5);
    tracker.onPlaybackProgress(
      const PlaybackProgress(
        position: Duration.zero,
        duration: Duration(seconds: 20),
        isPlaying: false,
      ),
    );

    tracker.startVideo(6);

    verifyNever(() => preferences.recordEngagement(any(), any()));
  });

  test('does not treat a short watch past 2 seconds as a skip', () {
    tracker.startVideo(5);
    tracker.onPlaybackProgress(playing(4));

    tracker.startVideo(6);

    verifyNever(() => preferences.recordEngagement(any(), any()));
  });

  test('closing the feed quickly is not a skip', () {
    tracker.startVideo(5);
    tracker.onPlaybackProgress(playing(1));

    tracker.stop();

    verifyNever(() => preferences.recordEngagement(any(), any()));
  });

  test('maps ratings to signals once per viewing', () {
    tracker.startVideo(5);
    tracker.onRated(9);
    tracker.onRated(10);

    tracker.startVideo(6);
    tracker.onRated(2);

    tracker.startVideo(7);
    tracker.onRated(6);

    verify(
      () => preferences.recordEngagement(5, EngagementSignal.ratedHigh),
    ).called(1);
    verify(
      () => preferences.recordEngagement(6, EngagementSignal.ratedLow),
    ).called(1);
    verifyNever(() => preferences.recordEngagement(7, any()));
  });

  test('ignores videos without a subcategory', () {
    tracker.startVideo(null);
    tracker.onPlaybackProgress(playing(10));
    tracker.onRated(9);
    tracker.stop();

    verifyNever(() => preferences.recordEngagement(any(), any()));
  });
}
