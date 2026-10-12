import 'package:beat_that/models/home_feed_cursor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeFeedCursor', () {
    test('round-trips server state and flags from the RPC', () {
      final rpcCursor = <String, dynamic>{
        'pagination': 'keyset',
        'windowStart': '2026-09-27T10:00:00.123456+00:00',
        'trackedSubcategoryIds': [3, 7],
        'personalized': {'score': '8.25', 'id': 'a'},
        'following': null,
        'trending': {'score': '6', 'id': 'b'},
        'discovery': {'createdAt': '2026-09-01T00:00:00+00:00', 'id': 'c'},
        'hasMorePersonalized': true,
        'hasMoreFollowing': false,
        'hasMoreTrending': true,
        'hasMoreDiscovery': false,
      };

      final cursor = HomeFeedCursor.fromMap(rpcCursor);

      expect(cursor.hasMoreFollowing, isFalse);
      expect(cursor.hasMoreDiscovery, isFalse);
      expect(cursor.hasMoreContent, isTrue);
      expect(cursor.serverState.containsKey('hasMoreTrending'), isFalse);
      expect(cursor.toMap(), equals(rpcCursor));
      expect(HomeFeedCursor.fromMap(cursor.toMap()), equals(cursor));
    });

    test('initial cursor sends only flags so the RPC starts a new session', () {
      const cursor = HomeFeedCursor.initial();

      expect(cursor.serverState, isEmpty);
      expect(cursor.toMap(), {
        'hasMorePersonalized': true,
        'hasMoreFollowing': true,
        'hasMoreTrending': true,
        'hasMoreDiscovery': true,
      });
    });

    test('reports no more content once every source is exhausted', () {
      final cursor = HomeFeedCursor.fromMap({
        'hasMorePersonalized': false,
        'hasMoreFollowing': false,
        'hasMoreTrending': false,
        'hasMoreDiscovery': false,
      });

      expect(cursor.hasMoreContent, isFalse);
    });
  });
}
