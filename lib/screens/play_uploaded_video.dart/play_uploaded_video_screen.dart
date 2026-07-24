import 'dart:async';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/sport.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/screens/play_uploaded_video.dart/bloc/play_uploaded_video_bloc.dart';
import 'package:beat_that/routes/app_router.dart';

/// Screen for playing uploaded videos
///
/// Can be used in two modes:
/// - Edit mode (shouldShowEditButtons=true): Shows video with edit/continue buttons
/// - View mode (shouldShowEditButtons=false): Full-screen video playback
class PlayUploadedVideoScreen extends StatefulWidget {
  final String videoPath;
  final bool shouldShowEditButtons;
  final Sport? sport;
  final String? selectedSubcategory;

  const PlayUploadedVideoScreen({
    super.key,
    required this.videoPath,
    this.shouldShowEditButtons = true,
    this.sport,
    this.selectedSubcategory,
  });

  @override
  State<PlayUploadedVideoScreen> createState() =>
      _PlayUploadedVideoScreenState();
}

class _PlayUploadedVideoScreenState extends State<PlayUploadedVideoScreen> {
  // Duration & timing
  static const Duration _controlsHideDuration = Duration(seconds: 3);

  // Layout & spacing
  static const double _padding16 = 16.0;
  static const double _padding12 = 12.0;

  // UI elements
  static const double _iconSize64 = 64.0;

  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void dispose() {
    _cancelControlsHide();
    super.dispose();
  }

  Widget _buildCoverVideoPlayer(
    VideoPlayerController videoController, {
    VoidCallback? onTap,
  }) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: videoController.value.size.width,
              height: videoController.value.size.height,
              child: VideoPlayer(videoController),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          PlayUploadedVideoBloc(videoPath: widget.videoPath)
            ..add(InitializeVideoEvent(widget.videoPath)),
      child: BlocConsumer<PlayUploadedVideoBloc, PlayUploadedVideoState>(
        listener: (context, state) {
          // Hide controls when video starts playing
          if (state is PlayUploadedVideoPlaying) {
            _cancelControlsHide();
            if (mounted) {
              setState(() => _showControls = false);
            }
          }

          // Show controls when video pauses or loads
          if (state is PlayUploadedVideoPaused ||
              state is PlayUploadedVideoReady) {
            _cancelControlsHide();
            if (mounted) {
              setState(() => _showControls = true);
            }
          }
        },
        builder: (context, state) {
          final bloc = context.read<PlayUploadedVideoBloc>();
          final videoController = bloc.videoController;

          // In view mode: full-screen with overlaid controls (like Instagram)
          // In edit mode: normal scaffold with appbar and FAB
          if (!widget.shouldShowEditButtons) {
            return _buildFullScreenVideoLayout(context, state, bloc);
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Video'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () {
                  context.read<PlayUploadedVideoBloc>().add(
                    const DisposeVideoEvent(),
                  );

                  Navigator.pop(context);
                },
              ),
            ),
            body: _buildBody(context, state),
            // Floating action button for continue (only in edit mode)
            floatingActionButton:
                videoController != null &&
                    (state is PlayUploadedVideoReady ||
                        state is PlayUploadedVideoPlaying ||
                        state is PlayUploadedVideoPaused)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final duration = videoController.value.duration;
                      context.goNamed(
                        'edit-thumbnail',
                        extra: EditThumbnailExtra(
                          videoPath: widget.videoPath,
                          videoDuration: duration,
                          sport: widget.sport!,
                          selectedSubcategory: widget.selectedSubcategory,
                        ),
                      );
                    },
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, PlayUploadedVideoState state) {
    if (state is PlayUploadedVideoLoading) {
      return BeatLoadingScreen(message: 'Loading video...');
    }

    if (state is PlayUploadedVideoError) {
      return ErrorScreen(
        message: 'Unable to load video',
        primaryButtonText: 'Retry',
        primaryButtonCallback: () {
          /* retry */
        },
        secondaryButtonText: 'Go Back',
        secondaryButtonCallback: () {
          /* navigate */
        },
      );
    }

    final bloc = context.read<PlayUploadedVideoBloc>();
    final videoController = bloc.videoController;

    if (videoController == null) {
      return const Center(child: Text('Failed to load video'));
    }

    // In edit mode: show layout with slider below
    return _buildEditModeLayout(context, state, videoController, bloc);
  }

  /// Full-screen video layout (like Instagram/TikTok)
  /// Video fills entire screen with overlaid controls that auto-hide
  Widget _buildFullScreenVideoLayout(
    BuildContext context,
    PlayUploadedVideoState state,
    PlayUploadedVideoBloc bloc,
  ) {
    if (state is PlayUploadedVideoLoading) {
      return Scaffold(body: BeatLoadingScreen(message: 'Loading video...'));
    }

    if (state is PlayUploadedVideoError) {
      return Scaffold(
        body: ErrorScreen(
          message: 'Unable to load video',
          primaryButtonText: 'Retry',
          primaryButtonCallback: () {
            bloc.add(InitializeVideoEvent(widget.videoPath));
          },
          secondaryButtonText: 'Go Back',
          secondaryButtonCallback: () {
            Navigator.pop(context);
          },
        ),
      );
    }

    final videoController = bloc.videoController;
    if (videoController == null) {
      return Scaffold(body: const Center(child: Text('Failed to load video')));
    }

    return Scaffold(
      body: Container(
        color: AppColors.black,
        child: Stack(
          children: [
            // Full-screen video player
            _buildCoverVideoPlayer(
              videoController,
              onTap: state is PlayUploadedVideoPlaying
                  ? () => _showControlsTemporarily()
                  : null,
            ),

            // Play/Pause button overlay (center)
            if (state is PlayUploadedVideoPaused ||
                state is PlayUploadedVideoReady)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: _iconSize64,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: () => bloc.add(const PlayVideoEvent()),
                  ),
                ),
              ),

            if (state is PlayUploadedVideoPlaying && _showControls)
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => bloc.add(const PauseVideoEvent()),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      iconSize: _iconSize64,
                      icon: const Icon(Icons.pause, color: Colors.white),
                      onPressed: null,
                    ),
                  ),
                ),
              ),

            // Top gradient + back button (only show when controls visible)
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.black.withValues(alpha: 0.6),
                        AppColors.black.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 8),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          bloc.add(const DisposeVideoEvent());
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom gradient + progress slider (only show when controls visible)
            if (_showControls &&
                (state is PlayUploadedVideoReady ||
                    state is PlayUploadedVideoPlaying ||
                    state is PlayUploadedVideoPaused))
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.black.withValues(alpha: 0.8),
                        AppColors.black.withValues(alpha: 0.4),
                        AppColors.black.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    bottom: _padding16,
                    left: _padding12,
                    right: _padding12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress slider
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: videoController,
                        builder: (context, value, child) {
                          return Slider(
                            value: value.position.inMilliseconds.toDouble(),
                            min: 0.0,
                            max: value.duration.inMilliseconds.toDouble(),
                            activeColor: AppColors.electricMagenta,
                            inactiveColor: AppColors.greyMedium.withValues(
                              alpha: 0.5,
                            ),
                            thumbColor: AppColors.electricMagenta,
                            overlayColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),
                            onChanged: (newValue) {
                              videoController.seekTo(
                                Duration(milliseconds: newValue.toInt()),
                              );
                            },
                          );
                        },
                      ),
                      // Time display
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: videoController,
                          builder: (context, value, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(value.position),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _formatDuration(value.duration),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Edit mode: Full-screen video with overlaid slider (like Instagram)
  /// Allows precise editing with full-screen video view
  Widget _buildEditModeLayout(
    BuildContext context,
    PlayUploadedVideoState state,
    VideoPlayerController videoController,
    PlayUploadedVideoBloc bloc,
  ) {
    return Container(
      color: AppColors.black,
      child: Stack(
        children: [
          // Full-screen video player
          _buildCoverVideoPlayer(
            videoController,
            onTap: state is PlayUploadedVideoPlaying
                ? () => _showControlsTemporarily()
                : null,
          ),

          // Play/Pause button overlay (center)
          if (state is PlayUploadedVideoPaused ||
              state is PlayUploadedVideoReady)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: _iconSize64,
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: () => bloc.add(const PlayVideoEvent()),
                ),
              ),
            ),

          if (state is PlayUploadedVideoPlaying && _showControls)
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => bloc.add(const PauseVideoEvent()),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: _iconSize64,
                    icon: const Icon(Icons.pause, color: Colors.white),
                    onPressed: null,
                  ),
                ),
              ),
            ),

          // Bottom gradient + progress slider (always visible in edit mode for precise editing)
          if (state is PlayUploadedVideoReady ||
              state is PlayUploadedVideoPlaying ||
              state is PlayUploadedVideoPaused)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.black.withValues(alpha: 0.9),
                      AppColors.black.withValues(alpha: 0.6),
                      AppColors.black.withValues(alpha: 0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.only(
                  bottom: _padding16,
                  left: _padding12,
                  right: _padding12,
                  top: _padding12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress slider
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: videoController,
                      builder: (context, value, child) {
                        return Slider(
                          value: value.position.inMilliseconds.toDouble(),
                          min: 0.0,
                          max: value.duration.inMilliseconds.toDouble(),
                          activeColor: AppColors.electricMagenta,
                          inactiveColor: AppColors.greyMedium.withValues(
                            alpha: 0.5,
                          ),
                          thumbColor: AppColors.electricMagenta,
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          onChanged: (newValue) {
                            videoController.seekTo(
                              Duration(milliseconds: newValue.toInt()),
                            );
                          },
                        );
                      },
                    ),
                    // Time display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: videoController,
                        builder: (context, value, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(value.position),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _formatDuration(value.duration),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Format duration to MM:SS format
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Cancel the auto-hide timer and clear the reference
  void _cancelControlsHide() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  /// Schedule the controls to auto-hide after the delay
  void _scheduleControlsHide() {
    // Only create timer if widget is still mounted
    if (!mounted) return;

    _hideControlsTimer = Timer(_controlsHideDuration, () {
      // Check mounted again before setState to prevent race condition
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  /// Show controls and schedule them to hide after delay
  void _showControlsTemporarily() {
    if (!mounted) return;

    _cancelControlsHide();
    setState(() => _showControls = true);
    _scheduleControlsHide();
  }
}
