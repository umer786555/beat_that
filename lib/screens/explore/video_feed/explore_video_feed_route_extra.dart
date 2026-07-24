import 'package:beat_that/screens/explore/bloc/explore_bloc.dart';

class ExploreVideoFeedExtra {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;
  final String query;
  final ExploreSearchMode searchMode;
  final String? selectedSportId;
  final int nextOffset;
  final bool hasMoreContent;

  const ExploreVideoFeedExtra({
    required this.videos,
    required this.initialIndex,
    required this.query,
    required this.searchMode,
    required this.nextOffset,
    required this.hasMoreContent,
    this.selectedSportId,
  });
}
