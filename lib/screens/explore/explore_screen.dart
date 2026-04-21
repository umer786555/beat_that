import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Explore screen - dummy screen for browsing content
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.explore,
              color: AppColors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Explore',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Browse and discover new content',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
