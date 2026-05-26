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
      username: decodedJson['username'] as String,
      profileUrl: decodedJson['profileUrl'] as String?,
    );
  }

  /// Clear the user's personal profile from local storage
  /// Used when user logs out or resets their profile
  Future<void> clearUserProfile() async {
    await _prefs.remove('user_personal_profile');
  }
}
