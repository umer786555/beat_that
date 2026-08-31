import 'package:beat_that/models/sport_video.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SportVideo.fromMap', () {
    test('reads snake_case rating fields', () {
      final video = SportVideo.fromMap({
        'id': 'video-1',
        'user_id': 'user-1',
        'user_video_id': 'my-video-1',
        'title': 'Test Video',
        'description': 'Description',
        'video_path': 'videos/test.mp4',
        'thumbnail_path': 'thumbs/test.png',
        'average_rating': 4.7,
        'bayesian_score': 87.5,
        'total_ratings': 42,
      });

      expect(video.averageRating, 4.7);
      expect(video.bayesianScore, 87.5);
      expect(video.totalRatings, 42);
      expect(video.ratingTargetId, 'my-video-1');
    });

    test('defaults rating fields when snake_case keys are missing', () {
      final video = SportVideo.fromMap({
        'id': 'video-2',
        'user_id': 'user-2',
        'user_video_id': 'my-video-2',
        'title': 'Fallback Video',
        'description': 'Description',
        'video_path': 'videos/fallback.mp4',
        'thumbnail_path': 'thumbs/fallback.png',
      });

      expect(video.averageRating, 0);
      expect(video.bayesianScore, 0);
      expect(video.totalRatings, 0);
      expect(video.ratingTargetId, 'my-video-2');
    });

    test('returns null rating target when user_video_id is missing', () {
      final video = SportVideo.fromMap({
        'id': 'video-3',
        'user_id': 'user-3',
        'title': 'Unrateable Video',
        'description': 'Description',
        'video_path': 'videos/unrateable.mp4',
        'thumbnail_path': 'thumbs/unrateable.png',
      });

      expect(video.ratingTargetId, isNull);
    });
  });
}
