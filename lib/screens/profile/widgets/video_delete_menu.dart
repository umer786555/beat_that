import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a delete menu followed by a confirmation dialog.
///
/// Returns `true` only when the user explicitly confirms deletion.
Future<bool> showVideoDeleteConfirmation(
  BuildContext context, {
  required bool isDark,
  required String videoTitle,
  required String thumbnailUrl,
}) async {
  final shouldOpenConfirmation = await showModalBottomSheet<bool>(
    context: context,
    builder: (BuildContext context) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar (Instagram style)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Delete option (red, Instagram style)
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context, true);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Divider
            Divider(
              height: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            // Cancel option
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, false);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Safe area padding for bottom
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      );
    },
  );

  if (shouldOpenConfirmation != true || !context.mounted) {
    return false;
  }

  final confirmed = await _showDeleteConfirmation(
    context,
    isDark: isDark,
    videoTitle: videoTitle,
    thumbnailUrl: thumbnailUrl,
  );

  return confirmed ?? false;
}

/// Shows Instagram-style delete confirmation dialog
Future<bool?> _showDeleteConfirmation(
  BuildContext context, {
  required bool isDark,
  required String videoTitle,
  required String thumbnailUrl,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: isDark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Delete video?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video preview thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumbnailUrl,
                    width: 200,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 160,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.video_library_outlined,
                          color: isDark ? Colors.grey[700] : Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Video title
                Text(
                  videoTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Warning message
                Text(
                  'This video will be deleted permanently and cannot be recovered.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, false);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Delete button (red, solid style)
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    },
  );
}
