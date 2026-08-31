import 'package:beat_that/constants/sports_data.dart';
import 'package:flutter/material.dart';

class NoResultsState extends StatelessWidget {
  const NoResultsState({
    required this.query,
    this.selectedSportId,
  });

  final String query;
  final String? selectedSportId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              selectedSportId == null
                  ? 'No matching videos for "$query"'
                  : query.isEmpty
                  ? 'No videos in ${getDisplayNameForSport(selectedSportId!)}'
                  : 'No matching videos for "$query" in ${getDisplayNameForSport(selectedSportId!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search or change your filters to see more videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
