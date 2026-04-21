
/// Application theme mode
enum AppThemeMode { light, dark }

extension AppThemeModeX on AppThemeMode {
  /// Check if this is dark mode
  bool get isDark => this == AppThemeMode.dark;

  /// Check if this is light mode
  bool get isLight => this == AppThemeMode.light;

  /// Toggle between light and dark
  AppThemeMode toggle() => this == AppThemeMode.dark
      ? AppThemeMode.light
      : AppThemeMode.dark;

  /// Convert enum to storage string (uses Dart's built-in .name)
  String toStorageString() => name;

  /// Convert string to AppThemeMode
  static AppThemeMode fromStorageString(String value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.dark, // Default to dark
    );
  }
}
