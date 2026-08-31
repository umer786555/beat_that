import 'package:beat_that/models/my_video.dart';
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
    required this.onReviewIssuesTap,
    required this.onDeleteConfirmed,
  });

  final MyVideo thumbnail;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onReviewIssuesTap;
  final ValueChanged<String> onDeleteConfirmed;

  Future<void> _handleLongPress(BuildContext context) async {
    HapticFeedback.heavyImpact();

    final shouldDelete = await showVideoDeleteConfirmation(
      context,
      isDark: isDark,
      videoTitle: thumbnail.title,
      thumbnailUrl: thumbnail.thumbnailUrl ?? '',
    );

    if (shouldDelete == true && context.mounted) {
      onDeleteConfirmed(thumbnail.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        onLongPress: () => _handleLongPress(context),
        borderRadius: BorderRadius.circular(8),
        splashFactory: InkSplash.splashFactory,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getBorderColor(context), width: 1.5),
          ),
          child: Stack(
            children: [
              AbsorbPointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: VideoThumbnailItem(
                    thumbnail: thumbnail,
                    isDark: isDark,
                    onTap: onOpen,
                    onLongPress: (_) => _handleLongPress(context),
                  ),
                ),
              ),
              if (thumbnail.approved == false)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              if (thumbnail.approved == false)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onReviewIssuesTap,
                      borderRadius: BorderRadius.circular(12),
                      child: _buildRejectedHint(context),
                    ),
                  ),
                ),
              // Approval Status Badge
              Positioned(top: 8, right: 8, child: _buildApprovalBadge(context)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(BuildContext context) {
    if (thumbnail.approved == true) {
      return Theme.of(context).colorScheme.outline.withValues(alpha: 0.08);
    } else if (thumbnail.approved == null) {
      return Colors.amber.withValues(alpha: 0.3);
    } else {
      return Colors.red.withValues(alpha: 0.4);
    }
  }

  Widget _buildRejectedHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap to review issues',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBadge(BuildContext context) {
    if (thumbnail.approved == true) {
      // Approved - Elegant small verification badge (TikTok/Instagram style)
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (thumbnail.approved == null) {
      // Pending - Subtle loading spinner (TikTok style)
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.9),
            ),
            strokeWidth: 2,
          ),
        ),
      );
    } else {
      // Rejected - Minimalist prohibition icon
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 16),
      );
    }
  }
}
