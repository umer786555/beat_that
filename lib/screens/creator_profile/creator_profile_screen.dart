import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/creator_profile/bloc/creator_profile_bloc.dart';
import 'package:beat_that/screens/profile/widgets/video_thumbnail_item.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CreatorProfileScreen extends StatelessWidget {
  const CreatorProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) =>
          CreatorProfileBloc(userId: userId)
            ..add(const LoadCreatorProfileEvent()),
      child: BlocBuilder<CreatorProfileBloc, CreatorProfileState>(
        builder: (context, state) {
          if (state is CreatorProfileLoading ||
              state is CreatorProfileInitial) {
            return const BeatLoadingScreen(message: 'Loading profile...');
          }

          if (state is CreatorProfileError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Creator Profile')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: isDark
                            ? AppColors.cyan
                            : AppColors.electricMagenta,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          context.read<CreatorProfileBloc>().add(
                            const LoadCreatorProfileEvent(),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final loadedState = state as CreatorProfileLoaded;

          return Scaffold(
            appBar: AppBar(title: Text(loadedState.profile.username)),
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.cyan
                                      : AppColors.electricMagenta,
                                  width: 2,
                                ),
                              ),
                              child:
                                  loadedState.profile.profileUrl != null &&
                                      loadedState.profile.profileUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        loadedState.profile.profileUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Icon(
                                                Icons.error_outline,
                                                size: 40,
                                                color: isDark
                                                    ? AppColors.cyan
                                                    : AppColors.electricMagenta,
                                              );
                                            },
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 40,
                                      color: isDark
                                          ? AppColors.cyan
                                          : AppColors.electricMagenta,
                                    ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loadedState.profile.username,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${loadedState.videos.length} ${loadedState.videos.length == 1 ? 'video' : 'videos'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                        ),
                      ],
                    ),
                  ),
                ),
                if (loadedState.videos.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No videos uploaded yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final thumbnail = loadedState.videos[index];
                      return VideoThumbnailItem(
                        thumbnail: thumbnail,
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          GoRouter.of(context).pushNamed(
                            'play-video',
                            extra: PlayUploadedVideoExtra(
                              videoPath: thumbnail.videoUrl,
                              shouldShowEditButtons: false,
                            ),
                          );
                        },
                      );
                    }, childCount: loadedState.videos.length),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
