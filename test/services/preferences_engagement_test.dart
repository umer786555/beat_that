import 'dart:convert';

import 'package:beat_that/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesService preferences;

  Future<void> setUpWith(Map<String, dynamic> engagement) async {
    SharedPreferences.setMockInitialValues({
      if (engagement.isNotEmpty) 'engagement_data': jsonEncode(engagement),
    });
    preferences = PreferencesService();
    await preferences.init();
  }

  String daysAgo(int days) =>
      DateTime.now().subtract(Duration(days: days)).toIso8601String();

  Future<Map<String, double>> topScores() async {
    final top = await preferences.getTopSubcategories(limit: 20);
    return {for (final entry in top) entry.key: entry.value as double};
  }

  group('recordEngagement', () {
    test('adds signal weights and ranks by score', () async {
      await setUpWith({});

      await preferences.recordEngagement(1, EngagementSignal.watched);
      await preferences.recordEngagement(2, EngagementSignal.watched);
      await preferences.recordEngagement(2, EngagementSignal.completed);
      await preferences.recordEngagement(3, EngagementSignal.ratedHigh);
      await preferences.recordEngagement(3, EngagementSignal.watched);

      final top = await preferences.getTopSubcategories();
      expect(top.map((entry) => entry.key), ['3', '2', '1']);
      expect(top.first.value, closeTo(4, 0.001));
    });

    test('negative signals lower a score and drop it at zero', () async {
      await setUpWith({});

      await preferences.recordEngagement(1, EngagementSignal.ratedHigh);
      await preferences.recordEngagement(1, EngagementSignal.quickSkip);
      expect((await topScores())['1'], closeTo(2.5, 0.001));

      await preferences.recordEngagement(1, EngagementSignal.ratedLow);
      await preferences.recordEngagement(1, EngagementSignal.ratedLow);
      expect(await topScores(), isEmpty);
    });

    test('negative signal on an unknown subcategory stores nothing', () async {
      await setUpWith({});

      await preferences.recordEngagement(7, EngagementSignal.quickSkip);

      expect(await topScores(), isEmpty);
    });

    test('back-to-back unawaited signals are not lost', () async {
      await setUpWith({});

      final first = preferences.recordEngagement(1, EngagementSignal.watched);
      final second = preferences.recordEngagement(
        1,
        EngagementSignal.completed,
      );
      await Future.wait([first, second]);

      expect((await topScores())['1'], closeTo(3, 0.001));
    });

    test('keeps at most 20 subcategories, dropping the weakest', () async {
      await setUpWith({});

      for (var id = 1; id <= 20; id++) {
        await preferences.recordEngagement(id, EngagementSignal.ratedHigh);
      }
      await preferences.recordEngagement(21, EngagementSignal.watched);

      final scores = await topScores();
      expect(scores.length, 20);
      expect(scores.containsKey('21'), isFalse);
    });
  });

  group('decay', () {
    test('halves a score every 14 days', () async {
      await setUpWith({
        '1': {'score': 4.0, 'updated_at': daysAgo(14)},
        '2': {'score': 4.0, 'updated_at': daysAgo(28)},
      });

      final scores = await topScores();
      expect(scores['1'], closeTo(2, 0.01));
      expect(scores['2'], closeTo(1, 0.01));
    });

    test('recent interest outranks a bigger but older one', () async {
      await setUpWith({
        'old': {'score': 10.0, 'updated_at': daysAgo(60)},
        'new': {'score': 2.0, 'updated_at': daysAgo(0)},
      });

      final top = await preferences.getTopSubcategories();
      expect(top.first.key, 'new');
    });

    test('new signal adds to the faded score, not the stored one', () async {
      await setUpWith({
        '1': {'score': 4.0, 'updated_at': daysAgo(14)},
      });

      await preferences.recordEngagement(1, EngagementSignal.watched);

      expect((await topScores())['1'], closeTo(3, 0.01));
    });

    test('ignores and cleans up the old view-count format', () async {
      await setUpWith({
        '1': {'views': 60, 'last_viewed': daysAgo(0)},
      });

      expect(await topScores(), isEmpty);

      await preferences.cleanupOldEngagement();
      expect(await preferences.getEngagementData(), isEmpty);
    });

    test(
      'cleanup removes fully faded interests and keeps active ones',
      () async {
        await setUpWith({
          'faded': {'score': 1.0, 'updated_at': daysAgo(90)},
          'active': {'score': 1.0, 'updated_at': daysAgo(1)},
        });

        await preferences.cleanupOldEngagement();

        final stored = await preferences.getEngagementData();
        expect(stored.keys, ['active']);
      },
    );
  });
}
