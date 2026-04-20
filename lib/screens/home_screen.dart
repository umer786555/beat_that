import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';

/// Home screen displayed when user is logged in
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = getIt<AuthService>();
    final user = authService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Beat That!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (user?.email != null)
              Text(
                'Logged in as: ${user?.email}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.grey,
                ),
              ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () async {
                // Show loading dialog
                if (!context.mounted) return;
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  await authService.logout();
                  // Don't pop the dialog manually - let GoRouter handle the redirect
                  // When authService.isLoggedIn() returns false, GoRouter will automatically
                  // redirect to the login screen, which will dismiss the dialog
                } catch (e) {
                  if (context.mounted) {
                    // Pop the dialog first, then show error
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
