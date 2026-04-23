import 'package:beat_that/constants/app_enums.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:beat_that/services/theme_service.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final ThemeService _themeService;
  AppThemeMode savedTheme = AppThemeMode.dark;

  ThemeBloc({required ThemeService themeService})
    : _themeService = themeService,
      super(const ThemeState(themeMode: AppThemeMode.dark)) {
    // Register event handlers
    on<LoadThemeEvent>(_onLoadTheme);
    on<ToggleThemeEvent>(_onToggleTheme);
  }

  /// Load saved theme preference on app startup
  Future<void> _onLoadTheme(
    LoadThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final savedTheme = await _themeService.getThemeMode();
      this.savedTheme = savedTheme;
      emit(ThemeState(themeMode: savedTheme));
    } catch (e) {
      // Default to dark theme on error
      emit(const ThemeState(themeMode: AppThemeMode.dark));
    }
  }

  /// Toggle between light and dark theme
  Future<void> _onToggleTheme(
    ToggleThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    final newMode = state.themeMode.toggle();
    await _themeService.setThemeMode(newMode);
    emit(state.copyWith(themeMode: newMode));
  }
}
