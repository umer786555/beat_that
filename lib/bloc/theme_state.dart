part of 'theme_bloc.dart';

class ThemeState extends Equatable {
  final AppThemeMode themeMode;

  const ThemeState({required this.themeMode});

  @override
  List<Object?> get props => [themeMode];

  ThemeState copyWith({AppThemeMode? themeMode}) {
    return ThemeState(themeMode: themeMode ?? this.themeMode);
  }
}
