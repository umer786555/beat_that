import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = getIt<AuthService>();
    final user = authService.getCurrentUser();

    return BlocProvider<ProfileBloc>(
      create: (context) => ProfileBloc()..add(const LoadProfileEvent()),
      child: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (prev, curr) {
          // Only listen when theme changes
          if (prev is ProfileLoaded && curr is ProfileLoaded) {
            return prev.currentTheme != curr.currentTheme;
          }
          return false;
        },
        listener: (context, state) {
          if (state is ProfileLoaded) {
            // Update ThemeBloc when theme changes in ProfileBloc
            context.read<ThemeBloc>().add(SetThemeEvent(state.currentTheme));
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  if (state is ProfileLoaded) {
                    final isDarkMode = state.currentTheme.isDark;
                    return IconButton(
                      icon: Icon(
                        isDarkMode ? Icons.light_mode : Icons.dark_mode,
                      ),
                      onPressed: () {
                        final newTheme = state.currentTheme.toggle();
                        context.read<ProfileBloc>().add(
                          ChangeThemeEvent(themeMode: newTheme),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.person, color: AppColors.green, size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (user?.email != null)
                  Text(
                    user!.email!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: AppColors.grey),
                  ),

                // Settings Section
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
