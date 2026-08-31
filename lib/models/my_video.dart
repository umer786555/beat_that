class MyVideo {
  /// Unique video identifier (UUID)
  final String id;

  /// Timestamp when the video was created
  final String createdAt;

  /// User ID (UUID) who uploaded the video
  final String userId;

  /// Video title (required)
  final String title;
  

  /// Video description (optional)
  final String? description;

  /// Storage path to the video object
  final String videoPath;

  /// Storage path to the thumbnail object
  final String thumbnailPath;

  /// Resolved thumbnail URL for display surfaces
  final String? thumbnailUrl;

  /// Number of times the video has been viewed
  final int viewCount;

  /// Average rating for the video (scale 0-100 with 2 decimal places)
  final double? averageRating;

  /// Number of likes received
  final int? likeCount;

  /// Sport subcategory ID associated with the video
  final double? subcategoryId;

  /// Sport ID associated with the video
  final String? sportId;

  /// Sport subcategory name associated with the video
  final String? subcategoryName;

  /// Whether the video has been approved by moderation
  final bool? approved;

  const MyVideo({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.title,
    this.description,
    required this.videoPath,
    required this.thumbnailPath,
    this.thumbnailUrl,
    this.viewCount = 0,
    this.averageRating,
    this.likeCount,
    this.subcategoryId,
    this.sportId,
    this.subcategoryName,
    this.approved,
  });

  /// Create MyVideo from JSON response
  factory MyVideo.fromJson(Map<String, dynamic> json) {
    return MyVideo(
      id: json['id'] as String,
      createdAt: json['created_at'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      videoPath: json['video_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      likeCount: json['like_count'] as int?,
      subcategoryId: (json['subcategory_id'] as num?)?.toDouble(),
      sportId: json['sport_id'] as String?,
      subcategoryName: json['subcategory_name'] as String?,
      approved: json['approved'] as bool?,
    );
  }

  /// Convert MyVideo to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt,
      'user_id': userId,
      'title': title,
      'description': description,
      'video_path': videoPath,
      'thumbnail_path': thumbnailPath,
      'thumbnailUrl': thumbnailUrl,
      'view_count': viewCount,
      'average_rating': averageRating,
      'like_count': likeCount,
      'subcategory_id': subcategoryId,
      'sport_id': sportId,
      'subcategory_name': subcategoryName,
      'approved': approved,
    };
  }

  /// Build the exact insert payload used when creating a my_videos row.
  static Map<String, dynamic> createInsertJson({
    required String userId,
    required String title,
    String? description,
    required String videoPath,
    required String thumbnailPath,
    String? sportId,
    int? subcategoryId,
    String? subcategoryName,
    String dataType = 'user_profile_video',
  }) {
    return {
      'user_id': userId,
      'title': title,
      'description': description ?? '',
      'video_path': videoPath,
      'thumbnail_path': thumbnailPath,
      'sport_id': sportId,
      'subcategory_id': subcategoryId,
      'subcategory_name': subcategoryName,
      'view_count': 0,
      'data_type': dataType,
    };
  }

  /// Create a copy of this object with optional field replacements
  MyVideo copyWith({
    String? id,
    String? createdAt,
    String? userId,
    String? title,
    String? description,
    String? videoPath,
    String? thumbnailPath,
    String? thumbnailUrl,
    int? viewCount,
    double? averageRating,
    int? likeCount,
    double? subcategoryId,
    String? sportId,
    String? subcategoryName,
    bool? approved,
  }) {
    return MyVideo(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoPath: videoPath ?? this.videoPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewCount: viewCount ?? this.viewCount,
      averageRating: averageRating ?? this.averageRating,
      likeCount: likeCount ?? this.likeCount,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      sportId: sportId ?? this.sportId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      approved: approved ?? this.approved,

    );
  }

  @override
  String toString() {
    return 'MyVideo(id: $id, title: $title, userId: $userId, videoPath: $videoPath, '
      'thumbnailPath: $thumbnailPath, thumbnailUrl: $thumbnailUrl, viewCount: $viewCount, likeCount: $likeCount, '
        'approved: $approved)';
  }
}
