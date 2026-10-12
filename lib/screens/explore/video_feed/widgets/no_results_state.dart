import 'package:flutter/material.dart';

class NoResultsState extends StatelessWidget {
  const NoResultsState({
    super.key,
    required this.query,
    this.selectedFilterLabel,
  });

  final String query;
  final String? selectedFilterLabel;

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
              selectedFilterLabel == null || selectedFilterLabel!.isEmpty
                  ? 'No matching videos for "$query"'
                  : query.isEmpty
                  ? 'No videos in $selectedFilterLabel'
                  : 'No matching videos for "$query" in $selectedFilterLabel',
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
