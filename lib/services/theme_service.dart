import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/constants/app_enums.dart';

/// Service to manage theme persistence
/// Handles saving and loading the user's theme preference
abstract class ThemeService {
  /// Get the saved theme mode
  Future<AppThemeMode> getThemeMode();

  /// Save the user's theme preference
  Future<void> setThemeMode(AppThemeMode themeMode);
}



/// SharedPreferences implementation of ThemeService
/// Persists theme preference to device storage
class SharedPreferencesThemeService implements ThemeService {
  static const String _themeKey = 'app_theme_mode';
  static const String _defaultTheme = 'dark';

  final PreferencesService _preferencesService;

  SharedPreferencesThemeService({required PreferencesService preferencesService})
      : _preferencesService = preferencesService;

  @override
  Future<AppThemeMode> getThemeMode() async {
    final storedValue = await _preferencesService.getStringWithDefault(
      _themeKey,
      _defaultTheme,
    );
    return AppThemeModeX.fromStorageString(storedValue);
  }

  @override
  Future<void> setThemeMode(AppThemeMode themeMode) async {
    await _preferencesService.setString(_themeKey, themeMode.toStorageString());
  }
}
