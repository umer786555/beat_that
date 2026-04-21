import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Stats screen - dummy screen for viewing statistics
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bar_chart,
              color: AppColors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Stats',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'View your performance and achievements',
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
