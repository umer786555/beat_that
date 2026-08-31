class VideoRating {
  final String videoId;
  final String userId;
  final int rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VideoRating({
    required this.videoId,
    required this.userId,
    required this.rating,
    this.createdAt,
    this.updatedAt,
  });

  factory VideoRating.fromJson(Map<String, dynamic> json) {
    return VideoRating(
      videoId: json['video_id'] as String,
      userId: json['user_id'] as String,
      rating: (json['rating'] as num).toInt(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'user_id': userId,
      'rating': rating,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  VideoRating copyWith({
    String? videoId,
    String? userId,
    int? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoRating(
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
