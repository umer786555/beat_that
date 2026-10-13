import 'package:beat_that/constants/app_strings.dart';

/// A category the user can upload a clip to, matched to its cover image by
/// file name (e.g. `sports.png`).
class UploadCategory {
  const UploadCategory._({
    required this.id,
    required this.title,
    required this.description,
    required this.routeName,
    this.imageUrl = '',
  });

  final String id;
  final String title;
  final String description;
  final String routeName;
  final String imageUrl;

  static const _all = [
    UploadCategory._(
      id: 'sports',
      title: AppStrings.sports,
      description: AppStrings.sportsCategoryDescription,
      routeName: 'sports-hub',
    ),
    UploadCategory._(
      id: 'gaming',
      title: AppStrings.gaming,
      description: AppStrings.gamingCategoryDescription,
      routeName: 'gaming-hub',
    ),
  ];

  /// Returns null for images with no matching category, so callers never
  /// show a category that can't be opened.
  static UploadCategory? fromImageUrl(String imageUrl) {
    final segments = Uri.tryParse(imageUrl)?.pathSegments ?? const [];
    final filename = segments.isNotEmpty ? segments.last : imageUrl;
    final id = filename.split('.').first.toLowerCase();

    for (final category in _all) {
      if (category.id == id) {
        return UploadCategory._(
          id: category.id,
          title: category.title,
          description: category.description,
          routeName: category.routeName,
          imageUrl: imageUrl,
        );
      }
    }
    return null;
  }
}
