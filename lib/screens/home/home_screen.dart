import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/screens/home/bloc/home_bloc.dart';

  // shared_preferences: ^2.2.2

/// Home screen displayed when user is logged in
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              context.read<HomeBloc>().add(const LogoutEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is NoUserProfile) {
            // Navigate to username setup screen
            context.go('/username-setup');
          } else if (state is UserProfileLoaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Welcome back!')),
            );
          }
        },
        builder: (context, state) {
          if (state is UserProfileLoaded) {
            return _buildHomeContent(state.userProfile.username);
          }
          // Show empty state while determining profile status
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHomeContent(String username) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.green, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Welcome to Beat That!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome, $username!',
            style: const TextStyle(fontSize: 16, color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}
