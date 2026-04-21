import 'package:shared_preferences/shared_preferences.dart';

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
}
