import 'package:beat_that/models/sport_video.dart';

/// Explore list state reached in the full-screen feed, handed back to the grid.
class ExploreFeedProgress {
  const ExploreFeedProgress({
    required this.query,
    required this.selectedSportId,
    required this.isRandomFeed,
    required this.videos,
    required this.currentIndex,
    required this.nextOffset,
    required this.hasMore,
    this.randomSeed,
    this.randomAfterId,
    this.randomHasWrapped = false,
  });

  final String query;
  final String? selectedSportId;
  final bool isRandomFeed;
  final List<SportVideo> videos;

  /// The video the viewer was on when they left the feed.
  final int currentIndex;
  final int nextOffset;
  final bool hasMore;
  final String? randomSeed;
  final String? randomAfterId;
  final bool randomHasWrapped;
}

/// Holds the latest progress from the open full-screen Explore feed.
class ExploreFeedProgressStore {
  ExploreFeedProgress? _latest;

  void save(ExploreFeedProgress progress) => _latest = progress;

  void clear() => _latest = null;

  ExploreFeedProgress? take() {
    final progress = _latest;
    _latest = null;
    return progress;
  }
}
