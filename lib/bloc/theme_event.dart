part of 'theme_bloc.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class LoadThemeEvent extends ThemeEvent {
  const LoadThemeEvent();
}

class ToggleThemeEvent extends ThemeEvent {
  const ToggleThemeEvent();
}

class SetThemeEvent extends ThemeEvent {
  final AppThemeMode themeMode;

  const SetThemeEvent(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}
