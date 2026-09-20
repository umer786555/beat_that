import 'package:beat_that/widgets/custom_back_button.dart';
import 'package:flutter/material.dart';

class VideoFeedDropdownMenu extends StatelessWidget {
  const VideoFeedDropdownMenu({super.key, this.onReportPressed});

  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'report' && onReportPressed != null) {
          onReportPressed!();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'report',
          child: Text(
            'Report',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class VideoFeedChrome extends StatelessWidget {
  const VideoFeedChrome({
    super.key,
    required this.isVisible,
    required this.onBackPressed,
    this.onReportPressed,
  });

  final bool isVisible;
  final VoidCallback onBackPressed;
  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: CustomBackButton(onPressed: onBackPressed),
          ),
        ),
        if (onReportPressed != null)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: VideoFeedDropdownMenu(
                onReportPressed: onReportPressed,
              ),
            ),
          ),
      ],
    );
  }
}