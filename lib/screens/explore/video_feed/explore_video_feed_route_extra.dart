import 'package:beat_that/models/sport_video.dart';

class ExploreVideoFeedExtra {
  final List<SportVideo> videos;
  final int initialIndex;
  final String query;
  final String? selectedSportId;
  final int nextOffset;
  final bool hasMoreContent;
  // These random-feed fields preserve the seeded continuation state when the
  // user jumps from the grid into the full-screen explore player.
  final bool isRandomFeed;
  final String? randomSeed;
  final String? randomAfterId;
  final bool randomHasWrapped;

  const ExploreVideoFeedExtra({
    required this.videos,
    required this.initialIndex,
    required this.query,
    required this.nextOffset,
    required this.hasMoreContent,
    this.selectedSportId,
    this.isRandomFeed = false,
    this.randomSeed,
    this.randomAfterId,
    this.randomHasWrapped = false,
  });
}
