class VideoThumbnailModel {
  /// Unique video identifier (UUID)
  final String id;

  /// Signed URL for the thumbnail image (7 days expiry)
  final String thumbnailUrl;

  /// Storage path for the video (used for playback resolution)
  final String videoPath;

  /// Video title
  final String title;

  /// Sport identifier associated with the video, when available
  final String? sportId;

  /// Sport subcategory identifier associated with the video, when available
  final int? subcategoryId;

  /// Sport subcategory name associated with the video, when available
  final String? subcategoryName;

  /// Video description
  final String description;

  /// Number of views
  final int viewCount;

  /// Average rating for the video (numeric in Supabase)
  final double averageRating;

  /// Timestamp when video was created (timestampz)
  final String createdAt;

  /// Storage path for the thumbnail (used for deletion)
  final String thumbnailPath;

  VideoThumbnailModel({
    required this.id,
    required this.thumbnailUrl,
    required this.videoPath,
    required this.title,
    this.sportId,
    this.subcategoryId,
    this.subcategoryName,
    required this.description,
    required this.viewCount,
    required this.averageRating,
    required this.createdAt,
    required this.thumbnailPath,
  });

  /// Create VideoThumbnailModel from JSON response
  factory VideoThumbnailModel.fromJson(Map<String, dynamic> json) {
    return VideoThumbnailModel(
      id: json['id'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      videoPath: json['video_path'] as String,
      title: json['title'] as String? ?? 'Untitled',
      sportId: json['sport_id'] as String?,
      subcategoryId: json['subcategory_id'] as int?,
      subcategoryName: json['subcategory_name'] as String?,
      description: json['description'] as String? ?? '',
      viewCount: json['view_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String,
      thumbnailPath: json['thumbnail_path'] as String,
    );
  }
}
