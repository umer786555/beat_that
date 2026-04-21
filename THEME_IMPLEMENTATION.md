# Theme Switching Implementation Guide

This guide explains how to implement and use the light/dark theme switching system in Beat That.

## System Overview

The theme system uses **Flutter BLoC** for state management and consists of:

1. **AppThemes** (`lib/constants/app_themes.dart`) - Define light and dark theme configurations
2. **ThemeService** (`lib/services/theme_service.dart`) - Persist theme preferences
3. **ThemeBloc** (`lib/bloc/theme_bloc.dart`) - Manage theme state and events
4. **ThemeToggleWidget** (`lib/widgets/theme_toggle_widget.dart`) - UI components for theme switching
5. **Updated Main** - BLoC provider setup and theme application

## How to Use

**Default Theme:** Dark mode

### 1. Add Theme Toggle to App Bar

```dart
import 'package:beat_that/widgets/theme_toggle_widget.dart';

AppBar(
  title: const Text('My Screen'),
  actions: [
    const ThemeToggleButton(),
  ],
)
```

### 2. Use Theme Selector Dialog in Settings

```dart
import 'package:beat_that/widgets/theme_toggle_widget.dart';

GestureDetector(
  onTap: () {
    showDialog(
      context: context,
      builder: (context) => const ThemeSelector(),
    );
  },
  child: const Text('Change Theme'),
)
```

### 3. Access Current Theme Mode Anywhere

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/bloc/theme_bloc.dart';

BlocBuilder<ThemeBloc, ThemeState>(
  builder: (context, state) {
    if (state.isDarkMode) {
      // Do something in dark mode
    } else {
      // Do something in light mode
    }
    return Container();
  },
)
```

### 4. Programmatically Toggle Theme

```dart
context.read<ThemeBloc>().add(const ToggleThemeEvent());
```

### 5. Set Specific Theme

```dart
// Set dark theme
context.read<ThemeBloc>().add(const SetThemeEvent('dark'));

// Set light theme
context.read<ThemeBloc>().add(const SetThemeEvent('light'));
```

## Customizing Themes

Edit `lib/constants/app_themes.dart` to customize:

- **Colors**: Change primary/secondary colors
- **Typography**: Adjust text styles
- **Component Styling**: Modify buttons, cards, inputs, etc.
- **Spacing & Corners**: Adjust padding, border radius

Example: Changing primary color
```dart
ColorScheme.fromSeed(
  seedColor: AppColors.purple,  // Change this
  brightness: Brightness.light,
)
```

## Persisting Theme Preference

Currently, the app uses `InMemoryThemeService` (theme resets on app restart).

### To persist across sessions:

1. Add `shared_preferences` to `pubspec.yaml`:
```yaml
dependencies:
  shared_preferences: ^2.2.0
```

2. Update `lib/services/theme_service.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesThemeService implements ThemeService {
  static const String _themeKey = 'theme_mode';

  @override
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'dark';
  }

  @override
  Future<void> setThemeMode(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode);
  }
}
```

3. Update `lib/service_locator.dart`:
```dart
getIt.registerSingleton<ThemeService>(
  SharedPreferencesThemeService(),
);
```

## Theme Structure

### Light Theme
- Background: White
- Card Background: Light grey (#F5F5F5)
- Text: Dark grey for body text
- Buttons: Purple (primary color)

### Dark Theme (Default)
- Background: Very dark (#121212)
- Card Background: Dark grey (#1E1E1E)
- Text: Light grey for body text
- Buttons: Light purple

## Best Practices

1. **Always use theme colors from AppColors** for consistency
2. **Use Theme.of(context)** to access current theme colors
3. **Test both themes** when adding new UI
4. **Use semantic colors** (success/error/warning) rather than hardcoding colors
5. **Leverage Material3 ColorScheme** for automatic color harmony

## Testing Themes

Run the app and:

1. Toggle light/dark mode using the theme button
2. Close and reopen app to verify persistence (after adding SharedPreferences)
3. Test all screens in both themes
4. Verify theme persists across app restarts (when using SharedPreferences)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Theme doesn't change | Ensure `BlocProvider` wraps the app in main.dart |
| Colors look wrong | Check that you're using Material3 colors, not hardcoded colors |
| Theme resets on restart | Add SharedPreferences (see persistence section) |
| Light theme text unreadable | Adjust text colors in `AppThemes.lightTheme` textTheme |
