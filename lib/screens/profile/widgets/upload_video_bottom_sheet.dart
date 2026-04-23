import 'package:flutter/material.dart';
import 'package:beat_that/widgets/interactive_button.dart';

class UploadVideoBottomSheet extends StatelessWidget {
  final VoidCallback onRecordVideoSelected;
  final VoidCallback onUploadFromGallerySelected;

  const UploadVideoBottomSheet({
    super.key,
    required this.onRecordVideoSelected,
    required this.onUploadFromGallerySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
            child: Text(
              'Upload Video',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // Record option
          _buildUploadOption(
            context,
            icon: Icons.videocam,
            title: 'Record Video',
            subtitle: 'Record a new video',
            iconColor: const Color(0xFF6366F1),
            onTap: () {
              onRecordVideoSelected();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          // Upload from gallery option
          _buildUploadOption(
            context,
            icon: Icons.photo_library,
            title: 'Upload from Gallery',
            subtitle: 'Choose from your library',
            iconColor: const Color(0xFF10B981),
            onTap: () {
              onUploadFromGallerySelected();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUploadOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: InteractiveButton(
        borderRadius: BorderRadius.circular(14),
        scaleDown: 0.97,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              // Icon with subtle background
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: iconColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: iconColor.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
