import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:beat_that/models/sport_video.dart';

class HomeVideoFeedSession {
  HomeVideoFeedSession({
    required this.id,
    required List<SportVideo> videos,
    required this.nextCursor,
    Set<String>? seenVideoIds,
    this.hasMoreContent = true,
  }) : videos = List<SportVideo>.from(videos),
       seenVideoIds =
           seenVideoIds ?? videos.map((video) => video.id).toSet();

  final String id;
  final List<SportVideo> videos;
  final Set<String> seenVideoIds;
  HomeFeedCursor nextCursor;
  bool hasMoreContent;
}

class HomeVideoFeedSessionStore {
  int _nextSessionId = 0;
  final Map<String, HomeVideoFeedSession> _sessions = {};

  String createSession({
    required List<SportVideo> videos,
    required HomeFeedCursor nextCursor,
    bool hasMoreContent = true,
  }) {
    _nextSessionId++;
    final id = 'home-feed-session-$_nextSessionId';
    _sessions[id] = HomeVideoFeedSession(
      id: id,
      videos: videos,
      nextCursor: nextCursor,
      hasMoreContent: hasMoreContent,
    );
    return id;
  }

  HomeVideoFeedSession? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  void appendVideos({
    required String sessionId,
    required List<SportVideo> videos,
    required HomeFeedCursor nextCursor,
    required bool hasMoreContent,
  }) {
    final session = _sessions[sessionId];
    if (session == null) {
      return;
    }

    session.videos.addAll(videos);
  session.nextCursor = nextCursor;
    session.hasMoreContent = hasMoreContent;

    for (final video in videos) {
      session.seenVideoIds.add(video.id);
    }
  }

  void removeSession(String sessionId) {
    _sessions.remove(sessionId);
  }
}
