import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_personal_profile.dart';

/// How strongly each viewer action changes interest in a subcategory.
enum EngagementSignal {
  watched(1),
  completed(2),
  ratedHigh(3),
  ratedLow(-2),
  quickSkip(-0.5);

  const EngagementSignal(this.weight);

  final double weight;
}

/// Service to manage application preferences using SharedPreferences
/// Provides a clean abstraction layer for storing and retrieving app-wide preferences
/// Must be initialized once at app startup via the init() method
class PreferencesService {
  late SharedPreferences _prefs;

  bool getBool(String key) {
    return _prefs.getBool(key) ?? false;
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  /// Initialize the SharedPreferences instance
  /// Must be called exactly once during app startup before using the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get a string preference with a default value
  /// Returns the stored value or the provided default if not found
  Future<String> getStringWithDefault(String key, String defaultValue) async {
    return _prefs.getString(key) ?? defaultValue;
  }

  /// Set a string preference
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  /// Save a user's personal profile
  Future<void> saveUserProfile(UserPersonalProfile profile) async {
    final profileJson = jsonEncode({
      'id': profile.id,
      'username': profile.username,
      'profileUrl': profile.profileUrl,
    });
    await _prefs.setString('user_personal_profile', profileJson);
  }

  /// Fetch a user's personal profile
  Future<UserPersonalProfile?> fetchUserProfile() async {
    final profileJson = _prefs.getString('user_personal_profile');
    if (profileJson == null) return null;

    final decodedJson = jsonDecode(profileJson) as Map<String, dynamic>;
    return UserPersonalProfile(
      id: decodedJson['id'] as String?,
      username: decodedJson['username'] as String,
      profileUrl: decodedJson['profileUrl'] as String?,
    );
  }

  /// Update only the username in the user's personal profile
  /// Preserves all other fields (id, profileUrl) from the existing profile
  /// This is more efficient than fetching, reconstructing, and saving the entire profile
  Future<void> updateUserProfileUsername(String newUsername) async {
    final profileJson = _prefs.getString('user_personal_profile');
    if (profileJson == null) return;

    final decodedJson = jsonDecode(profileJson) as Map<String, dynamic>;
    decodedJson['username'] = newUsername;

    await _prefs.setString('user_personal_profile', jsonEncode(decodedJson));
  }

  /// Clear the user's personal profile from local storage
  /// Used when user logs out or resets their profile
  Future<void> clearUserProfile() async {
    await _prefs.remove('user_personal_profile');
  }

  static const String _engagementKey = 'engagement_data';
  static const double _halfLifeDays = 14;
  static const double _minActiveScore = 0.05;
  static const int _maxTrackedSubcategories = 20;

  /// Adjusts interest in [subcategoryId] by [signal], after fading the
  /// existing score to today.
  Future<void> recordEngagement(
    int subcategoryId,
    EngagementSignal signal,
  ) async {
    try {
      final engagement = _readEngagement();
      final now = DateTime.now();
      final key = subcategoryId.toString();
      final updatedScore =
          _currentScore(engagement[key], now) + signal.weight;

      if (updatedScore <= 0) {
        engagement.remove(key);
      } else {
        engagement[key] = {
          'score': updatedScore,
          'updated_at': now.toIso8601String(),
        };
      }

      if (engagement.length > _maxTrackedSubcategories) {
        final weakestKey = engagement.keys.reduce(
          (a, b) =>
              _currentScore(engagement[a], now) <=
                  _currentScore(engagement[b], now)
              ? a
              : b,
        );
        engagement.remove(weakestKey);
      }

      await _prefs.setString(_engagementKey, jsonEncode(engagement));
    } catch (e) {
      print('Error recording engagement: $e');
    }
  }

  /// Subcategories ranked by current (faded) interest score, highest first.
  Future<List<MapEntry<String, dynamic>>> getTopSubcategories({
    int limit = 5,
  }) async {
    try {
      final now = DateTime.now();
      final scored =
          _readEngagement().entries
              .map((entry) => MapEntry(entry.key, _currentScore(entry.value, now)))
              .where((entry) => entry.value >= _minActiveScore)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      return scored.take(limit).toList();
    } catch (e) {
      print('Error getting top subcategories: $e');
      return [];
    }
  }

  /// Removes subcategories whose interest has faded to almost nothing.
  Future<void> cleanupOldEngagement() async {
    try {
      final engagement = _readEngagement();
      final now = DateTime.now();
      engagement.removeWhere(
        (_, value) => _currentScore(value, now) < _minActiveScore,
      );

      await _prefs.setString(_engagementKey, jsonEncode(engagement));
    } catch (e) {
      print('Error cleaning up old engagement data: $e');
    }
  }

  Map<String, dynamic> _readEngagement() {
    final engagementJson = _prefs.getString(_engagementKey);
    if (engagementJson == null) return {};
    return jsonDecode(engagementJson) as Map<String, dynamic>;
  }

  double _currentScore(Object? entry, DateTime now) {
    if (entry is! Map) return 0;

    final score = (entry['score'] as num?)?.toDouble() ?? 0;
    final updatedAt = DateTime.tryParse(entry['updated_at'] as String? ?? '');
    if (updatedAt == null) return score;

    final elapsedDays =
        now.difference(updatedAt).inSeconds / Duration.secondsPerDay;
    if (elapsedDays <= 0) return score;

    return score * math.pow(0.5, elapsedDays / _halfLifeDays);
  }

  /// Get all engagement data for debugging or analysis
  /// Returns map of subcategoryId -> {views, last_viewed}
  Future<Map<String, dynamic>> getEngagementData() async {
    try {
      final engagementJson = _prefs.getString('engagement_data');
      if (engagementJson == null) return {};

      return jsonDecode(engagementJson) as Map<String, dynamic>;
    } catch (e) {
      print('Error getting engagement data: $e');
      return {};
    }
  }

  /// Clear all engagement data (used for logout or reset)
  Future<void> clearEngagement() async {
    try {
      await _prefs.remove('engagement_data');
    } catch (e) {
      print('Error clearing engagement data: $e');
    }
  }
}
