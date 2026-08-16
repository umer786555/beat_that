import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_personal_profile.dart';

/// Service to manage application preferences using SharedPreferences
/// Provides a clean abstraction layer for storing and retrieving app-wide preferences
/// Must be initialized once at app startup via the init() method
class PreferencesService {
  late SharedPreferences _prefs;

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

  /// Track a video view for a subcategory
  /// Increments view count and updates last_viewed timestamp
  /// Automatically enforces max 20 categories by removing oldest viewed
  Future<void> trackVideoView(String subcategoryId) async {
    try {
      final engagementJson = _prefs.getString('engagement_data');
      Map<String, dynamic> engagement = {};

      if (engagementJson != null) {
        engagement = jsonDecode(engagementJson) as Map<String, dynamic>;
      }

      final now = DateTime.now().toIso8601String();

      // Create new entry or update existing one
      if (engagement.containsKey(subcategoryId)) {
        final entry = engagement[subcategoryId] as Map<String, dynamic>;
        entry['views'] = (entry['views'] as int) + 1;
        entry['last_viewed'] = now;
      } else {
        engagement[subcategoryId] = {'views': 1, 'last_viewed': now};
      }

      // Enforce max 20 categories - remove oldest if we exceed limit
      if (engagement.length > 20) {
        final sortedByTime = engagement.entries.toList()
          ..sort((a, b) => DateTime.parse(a.value['last_viewed'] as String)
              .compareTo(DateTime.parse(b.value['last_viewed'] as String)));
        
        engagement.remove(sortedByTime.first.key);
      }

      await _prefs.setString('engagement_data', jsonEncode(engagement));
    } catch (e) {
      print('Error tracking video view: $e');
    }
  }

  /// Get top engaged subcategories sorted by view count (highest first)
  /// Returns list of MapEntry with subcategory ID and engagement data
  /// Limit defaults to 5, can be customized
  Future<List<MapEntry<String, dynamic>>> getTopSubcategories(
      {int limit = 5}) async {
    try {
      final engagementJson = _prefs.getString('engagement_data');
      if (engagementJson == null) return [];

      final engagement = jsonDecode(engagementJson) as Map<String, dynamic>;

      // Convert to list and sort by view count (descending)
      final sortedList = engagement.entries.toList()
        ..sort((a, b) =>
            (b.value['views'] as int).compareTo(a.value['views'] as int));

      return sortedList.take(limit).toList();
    } catch (e) {
      print('Error getting top subcategories: $e');
      return [];
    }
  }

  /// Clean up engagement data older than 30 days
  /// Removes any subcategory not viewed in the last 30 days
  /// Call this on app launch or periodically to maintain fresh data
  Future<void> cleanupOldEngagement() async {
    try {
      final engagementJson = _prefs.getString('engagement_data');
      if (engagementJson == null) return;

      final engagement = jsonDecode(engagementJson) as Map<String, dynamic>;
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

      // Remove entries older than 30 days
      engagement.removeWhere((key, value) {
        final lastViewed = DateTime.parse(value['last_viewed'] as String);
        return lastViewed.isBefore(thirtyDaysAgo);
      });

      await _prefs.setString('engagement_data', jsonEncode(engagement));
    } catch (e) {
      print('Error cleaning up old engagement data: $e');
    }
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
