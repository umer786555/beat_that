import 'package:beat_that/widgets/permission_denied_card.dart';
import 'package:beat_that/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app_settings/app_settings.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/video_picker_service.dart';
import 'package:beat_that/bloc/theme_bloc.dart';
import 'package:beat_that/screens/profile/bloc/profile_bloc.dart';
import 'package:beat_that/screens/profile/widgets/upload_video_bottom_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = locator<AuthService>();
    final videoPickerService = locator<VideoPickerService>();
    final user = authService.getCurrentUser();

    return BlocProvider<ProfileBloc>(
      create: (context) => ProfileBloc()..add(const LoadProfileEvent()),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {},
        // Build UI based on state
        builder: (context, state) {
          final isDark = context.watch<ThemeBloc>().state.themeMode.isDark;
          if (state is CameraPermissionDenied) {
            return Scaffold(
              appBar: AppBar(title: const Text(AppStrings.profile)),
              body: PermissionDeniedCard(
                icon: Icons.camera_alt,
                title: AppStrings.cameraAccessRequired,
                body: AppStrings.cameraPermissionBody,
                buttonText: AppStrings.openSettings,
                onButtonPressed: () {
                  AppSettings.openAppSettings(type: AppSettingsType.camera);
                },
              ),
            );
          }
          if (state is ProfileLoaded) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
              },
              child: Scaffold(
                appBar: AppBar(
                  title: const Text(AppStrings.profile),
                  actions: [
                    IconButton(
                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      onPressed: () {
                        context.read<ThemeBloc>().add(ToggleThemeEvent());
                      },
                    ),
                  ],
                ),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        AppStrings.profile,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    // Show upload options bottom sheet

                    if (state.cameraPermissionEnabled == true) {
                      await showModalBottomSheet(
                        context: context,
                        builder: (_) => UploadVideoBottomSheet(
                          onRecordVideoSelected: () async =>
                              await videoPickerService.openCameraAndHandleVideo(
                                (video) {
                                  GoRouter.of(context).pushNamed(
                                    'edit-uploaded-video',
                                    extra: video.path,
                                  );
                                },
                              ),
                          onUploadFromGallerySelected: () async =>
                              await videoPickerService
                                  .openGalleryAndHandleVideo((video) {
                                    GoRouter.of(context).pushNamed(
                                      'edit-uploaded-video',
                                      extra: video.path,
                                    );
                                  }),
                        ),
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                      );
                      return;
                    } else {
                      // Request camera permission
                      context.read<ProfileBloc>().add(
                        const RequestCameraPermissionEvent(),
                      );
                    }
                  },
                  backgroundColor: isDark
                      ? AppColors.cyan.withValues(
                          alpha: 0.9,
                        ) // Neon cyan for dark theme
                      : AppColors
                            .electricMagenta, // Vibrant magenta for light theme
                  foregroundColor: isDark
                      ? AppColors
                            .white // High contrast with bright cyan
                      : AppColors.white, // Elegant contrast with magenta
                  icon: const Icon(Icons.videocam),
                  label: const Text(AppStrings.recordVideo),
                  tooltip: AppStrings.recordVideo,
                ),
              ),
            );
          }

          // Loading state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
