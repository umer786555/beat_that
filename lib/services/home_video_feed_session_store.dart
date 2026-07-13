class HomeVideoFeedSession {
  HomeVideoFeedSession({
    required this.id,
    required List<Map<String, dynamic>> videos,
    required this.nextOffset,
    Set<String>? seenVideoIds,
    this.hasMoreContent = true,
  }) : videos = List<Map<String, dynamic>>.from(videos),
       seenVideoIds =
           seenVideoIds ??
           videos
               .map((video) => video['id'] as String?)
               .whereType<String>()
               .toSet();

  final String id;
  final List<Map<String, dynamic>> videos;
  final Set<String> seenVideoIds;
  int nextOffset;
  bool hasMoreContent;
}

class HomeVideoFeedSessionStore {
  int _nextSessionId = 0;
  final Map<String, HomeVideoFeedSession> _sessions = {};

  String createSession({
    required List<Map<String, dynamic>> videos,
    required int nextOffset,
    bool hasMoreContent = true,
  }) {
    _nextSessionId++;
    final id = 'home-feed-session-$_nextSessionId';
    _sessions[id] = HomeVideoFeedSession(
      id: id,
      videos: videos,
      nextOffset: nextOffset,
      hasMoreContent: hasMoreContent,
    );
    return id;
  }

  HomeVideoFeedSession? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  void appendVideos({
    required String sessionId,
    required List<Map<String, dynamic>> videos,
    required int nextOffset,
    required bool hasMoreContent,
  }) {
    final session = _sessions[sessionId];
    if (session == null) {
      return;
    }

    session.videos.addAll(videos);
    session.nextOffset = nextOffset;
    session.hasMoreContent = hasMoreContent;

    for (final video in videos) {
      final videoId = video['id'] as String?;
      if (videoId != null) {
        session.seenVideoIds.add(videoId);
      }
    }
  }

  void removeSession(String sessionId) {
    _sessions.remove(sessionId);
  }
}
