import 'package:beat_that/constants/app_enums.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:beat_that/services/theme_service.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final ThemeService _themeService;

  ThemeBloc({required ThemeService themeService})
      : _themeService = themeService,
        super(const ThemeState(themeMode: AppThemeMode.dark)) {
    // Register event handlers
    on<LoadThemeEvent>(_onLoadTheme);
    on<ToggleThemeEvent>(_onToggleTheme);
    on<SetThemeEvent>(_onSetTheme);
  }

  /// Load saved theme preference on app startup
  Future<void> _onLoadTheme(
    LoadThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final savedTheme = await _themeService.getThemeMode();
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

  /// Set a specific theme mode
  Future<void> _onSetTheme(
    SetThemeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    await _themeService.setThemeMode(event.themeMode);
    emit(ThemeState(themeMode: event.themeMode));
  }
}