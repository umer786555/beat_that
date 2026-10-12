import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';
import 'package:beat_that/services/home_video_feed_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SportVideo video(String id) => SportVideo(
    id: id,
    userId: 'user-1',
    title: id,
    description: '',
    videoPath: '$id.mp4',
    thumbnailPath: '$id.jpg',
  );

  test('hands the session back with appended videos and current index', () {
    final store = HomeVideoFeedSessionStore();
    final sessionId = store.createSession(
      videos: [video('a')],
      nextCursor: const HomeFeedCursor.initial(),
      initialIndex: 0,
    );

    store.appendVideos(
      sessionId: sessionId,
      videos: [video('b')],
      nextCursor: const HomeFeedCursor(hasMoreFollowing: false),
      hasMoreContent: false,
    );
    store.updateCurrentIndex(sessionId, 1);

    final session = store.takeSession(sessionId);
    expect(session?.videos.map((v) => v.id), ['a', 'b']);
    expect(session?.currentIndex, 1);
    expect(session?.hasMoreContent, isFalse);
    expect(store.takeSession(sessionId), isNull);
  });
}
