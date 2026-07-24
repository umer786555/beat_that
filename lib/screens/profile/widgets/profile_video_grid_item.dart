import 'package:beat_that/models/video_thumbnail_model.dart';
import 'package:beat_that/screens/profile/widgets/video_delete_menu.dart';
import 'package:beat_that/screens/profile/widgets/video_thumbnail_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileVideoGridItem extends StatelessWidget {
  const ProfileVideoGridItem({
    super.key,
    required this.thumbnail,
    required this.isDark,
    required this.onOpen,
    required this.onDeleteConfirmed,
  });

  final VideoThumbnailModel thumbnail;
  final bool isDark;
  final VoidCallback onOpen;
  final ValueChanged<String> onDeleteConfirmed;

  Future<void> _handleLongPress(BuildContext context) async {
    HapticFeedback.heavyImpact();

    final shouldDelete = await showVideoDeleteConfirmation(
      context,
      isDark: isDark,
      videoTitle: thumbnail.title,
      thumbnailUrl: thumbnail.thumbnailUrl,
    );

    if (shouldDelete == true && context.mounted) {
      onDeleteConfirmed(thumbnail.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VideoThumbnailItem(
      thumbnail: thumbnail,
      isDark: isDark,
      onTap: onOpen,
      onLongPress: (_) => _handleLongPress(context),
    );
  }
}
