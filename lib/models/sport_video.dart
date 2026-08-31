import 'package:equatable/equatable.dart';

class SportVideo extends Equatable {
  const SportVideo({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.videoPath,
    required this.thumbnailPath,
    this.userVideoId,
    this.thumbnailUrl,
    this.username,
    this.sportId,
    this.createdAt,
    this.viewCount = 0,
    this.averageRating = 0,
    this.bayesianScore = 0,
    this.totalRatings = 0,
    this.source,
    this.sourceOrder,
    this.compositeScore,
  });

  final String id;
  final String userId;
  final String? userVideoId;
  final String title;
  final String description;
  final String videoPath;
  final String thumbnailPath;
  final String? thumbnailUrl;
  final String? username;
  final String? sportId;
  final String? createdAt;
  final int viewCount;
  final double averageRating;
  final double bayesianScore;
  final int totalRatings;
  final String? source;
  final int? sourceOrder;
  final double? compositeScore;

  String? get ratingTargetId {
    final value = userVideoId?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  factory SportVideo.fromMap(Map<String, dynamic> map) {
    return SportVideo(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userVideoId: map['user_video_id'] as String?,
      title: map['title'] as String? ?? 'Untitled',
      description: map['description'] as String? ?? '',
      videoPath: map['video_path'] as String? ?? '',
      thumbnailPath: map['thumbnail_path'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      username: _readUsername(map),
      sportId: map['sport_id'] as String?,
      createdAt: map['created_at'] as String?,
      viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
      averageRating: (map['average_rating'] as num?)?.toDouble() ?? 0,
      bayesianScore: (map['bayesian_score'] as num?)?.toDouble() ?? 0,
      totalRatings: (map['total_ratings'] as num?)?.toInt() ?? 0,
      source: map['source'] as String?,
      sourceOrder: (map['_source_order'] as num?)?.toInt(),
      compositeScore: (map['_composite_score'] as num?)?.toDouble(),
    );
  }

  static String? _readUsername(Map<String, dynamic> map) {
    final directUsername = map['username'] as String?;
    if (directUsername != null && directUsername.isNotEmpty) {
      return directUsername;
    }

    final nestedProfile = map['user_personal_profiles'];
    if (nestedProfile is Map<String, dynamic>) {
      return nestedProfile['username'] as String?;
    }

    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_video_id': userVideoId,
      'title': title,
      'description': description,
      'video_path': videoPath,
      'thumbnail_path': thumbnailPath,
      'thumbnailUrl': thumbnailUrl,
      'username': username,
      'sport_id': sportId,
      'created_at': createdAt,
      'view_count': viewCount,
      'average_rating': averageRating,
      'bayesian_score': bayesianScore,
      'total_ratings': totalRatings,
      'source': source,
      '_source_order': sourceOrder,
      '_composite_score': compositeScore,
    };
  }

  SportVideo copyWith({
    String? id,
    String? userId,
    String? userVideoId,
    String? title,
    String? description,
    String? videoPath,
    String? thumbnailPath,
    String? thumbnailUrl,
    String? username,
    String? sportId,
    String? createdAt,
    int? viewCount,
    double? averageRating,
    double? bayesianScore,
    int? totalRatings,
    String? source,
    int? sourceOrder,
    double? compositeScore,
  }) {
    return SportVideo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userVideoId: userVideoId ?? this.userVideoId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoPath: videoPath ?? this.videoPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      username: username ?? this.username,
      sportId: sportId ?? this.sportId,
      createdAt: createdAt ?? this.createdAt,
      viewCount: viewCount ?? this.viewCount,
      averageRating: averageRating ?? this.averageRating,
      bayesianScore: bayesianScore ?? this.bayesianScore,
      totalRatings: totalRatings ?? this.totalRatings,
      source: source ?? this.source,
      sourceOrder: sourceOrder ?? this.sourceOrder,
      compositeScore: compositeScore ?? this.compositeScore,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    userVideoId,
    title,
    description,
    videoPath,
    thumbnailPath,
    thumbnailUrl,
    username,
    sportId,
    createdAt,
    viewCount,
    averageRating,
    bayesianScore,
    totalRatings,
    source,
    sourceOrder,
    compositeScore,
  ];
}