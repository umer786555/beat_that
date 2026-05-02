import 'dart:async';
import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:beat_that/widgets/loading_screen.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:beat_that/screens/play_uploaded_video.dart/bloc/play_uploaded_video_bloc.dart';

/// Screen for playing uploaded videos
class PlayUploadedVideoScreen extends StatefulWidget {
  final String videoPath;

  const PlayUploadedVideoScreen({super.key, required this.videoPath});

  @override
  State<PlayUploadedVideoScreen> createState() =>
      _PlayUploadedVideoScreenState();
}

class _PlayUploadedVideoScreenState extends State<PlayUploadedVideoScreen> {
  // Duration & timing
  static const Duration _controlsHideDuration = Duration(seconds: 3);

  // Layout & spacing
  static const double _radius8 = 8.0;
  static const double _padding16 = 16.0;
  static const double _padding12 = 12.0;
  static const double _horizontalPadding8 = 8.0;

  // UI elements
  static const double _iconSize64 = 64.0;

  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void dispose() {
    _cancelControlsHide();
    super.dispose();
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
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, PlayUploadedVideoState state) {
    if (state is PlayUploadedVideoLoading) {
      return MissileLoadingScreen(message: 'Loading video...');
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

    return Column(
      children: [
        Flexible(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding8,
              vertical: _padding16,
            ),
            child: Center(
              child: _buildVideoPlayer(
                state,
                videoController,
                onPlay: () => bloc.add(const PlayVideoEvent()),
                onPause: () => bloc.add(const PauseVideoEvent()),
              ),
            ),
          ),
        ),

        if (state is PlayUploadedVideoReady ||
            state is PlayUploadedVideoPlaying ||
            state is PlayUploadedVideoPaused)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _padding16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: videoController,
                  builder: (context, value, child) {
                    return Slider(
                      value: value.position.inMilliseconds.toDouble(),
                      min: 0.0,
                      max: value.duration.inMilliseconds.toDouble(),
                      activeColor: AppColors.electricMagenta,
                      inactiveColor: AppColors.greyMedium,
                      thumbColor: AppColors.electricMagenta,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      onChanged: (newValue) {
                        videoController.seekTo(
                          Duration(milliseconds: newValue.toInt()),
                        );
                      },
                    );
                  },
                ),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: videoController,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(value.position)),
                        Text(_formatDuration(value.duration)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: _padding12),
              ],
            ),
          ),

        // Spacer to push buttons to bottom
        const Spacer(),

        // Action buttons at bottom
        if (state is PlayUploadedVideoReady ||
            state is PlayUploadedVideoPlaying ||
            state is PlayUploadedVideoPaused)
          Padding(
            padding: const EdgeInsets.all(_padding16),
            child: Row(
              children: [
                Expanded(
                  child: InteractiveButton(
                    onTap: () {
                      context.read<PlayUploadedVideoBloc>().add(
                        const DisposeVideoEvent(),
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: _padding16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.electricMagenta),
                        borderRadius: BorderRadius.circular(_radius8),
                      ),
                      child: const Text(
                        'Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.electricMagenta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: _padding16),
                Expanded(
                  child: InteractiveButton(
                    onTap: () {
                      final duration = videoController.value.duration;
                      context.goNamed(
                        'edit-thumbnail',
                        extra: (widget.videoPath, duration),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: _padding16),
                      decoration: BoxDecoration(
                        color: AppColors.electricMagenta,
                        borderRadius: BorderRadius.circular(_radius8),
                      ),
                      child: const Text(
                        'Continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Format duration to MM:SS format
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildVideoPlayer(
    PlayUploadedVideoState state,
    VideoPlayerController videoController, {
    required VoidCallback onPlay,
    required VoidCallback onPause,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius8),
      child: AspectRatio(
        aspectRatio: videoController.value.aspectRatio,
        child: Stack(
          children: [
            GestureDetector(
              onTap: state is PlayUploadedVideoPlaying
                  ? () => _showControlsTemporarily()
                  : null,
              child: VideoPlayer(videoController),
            ),
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
                    onPressed: onPlay,
                  ),
                ),
              ),
            if (state is PlayUploadedVideoPlaying && _showControls)
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPause,
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
          ],
        ),
      ),
    );
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
