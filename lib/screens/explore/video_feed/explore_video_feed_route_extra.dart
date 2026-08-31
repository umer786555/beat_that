import 'package:beat_that/models/sport_video.dart';

class ExploreVideoFeedExtra {
  final List<SportVideo> videos;
  final int initialIndex;
  final String query;
  final String? selectedSportId;
  final int nextOffset;
  final bool hasMoreContent;

  const ExploreVideoFeedExtra({
    required this.videos,
    required this.initialIndex,
    required this.query,
    required this.nextOffset,
    required this.hasMoreContent,
    this.selectedSportId,
  });
}
