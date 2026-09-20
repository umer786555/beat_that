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

  static const double _borderRadius = 8.0;
  static const double _borderWidth = 1.5;

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
    final borderRadius = BorderRadius.circular(_borderRadius);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: () => _handleLongPress(context),
        borderRadius: borderRadius,
        splashFactory: InkSplash.splashFactory,
        child: Container(
          // Paint the border over the thumbnail instead of creating
          // padding between the border and thumbnail.
          foregroundDecoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: _getBorderColor(context),
              width: _borderWidth,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(),

              // Rejected overlay
              if (thumbnail.approved == false)
                _buildRejectedOverlay(),

              // Rejected review action
              if (thumbnail.approved == false)
                _buildRejectedAction(context),

              // Approval status badge
              _buildStatusBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return AbsorbPointer(
      child: VideoThumbnailItem(
        thumbnail: thumbnail,
        isDark: isDark,
        onTap: onOpen,
        onLongPress: (_) {
          // Long press is handled by the parent InkWell.
        },
      ),
    );
  }

  Widget _buildRejectedOverlay() {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildRejectedAction(BuildContext context) {
    return Positioned(
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
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: _buildApprovalBadge(),
    );
  }

  Color _getBorderColor(BuildContext context) {
    if (thumbnail.approved == true) {
      return Theme.of(context)
          .colorScheme
          .outline
          .withValues(alpha: 0.08);
    }

    if (thumbnail.approved == null) {
      return Colors.amber.withValues(alpha: 0.3);
    }

    return Colors.red.withValues(alpha: 0.4);
  }

  Widget _buildRejectedHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 16,
          ),
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

  Widget _buildApprovalBadge() {
    if (thumbnail.approved == true) {
      return _buildBadge(
        color: Colors.blue,
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 16,
        ),
      );
    }

    if (thumbnail.approved == null) {
      return _buildBadge(
        color: Colors.orange.withValues(alpha: 0.9),
        padding: 5,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }

    return _buildBadge(
      color: Colors.red.withValues(alpha: 0.9),
      child: const Icon(
        Icons.close,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildBadge({
    required Color color,
    required Widget child,
    double padding = 4,
  }) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}