part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object> get props => [];
}

class LoadProfileEvent extends ProfileEvent {
  const LoadProfileEvent();
}

class ChangeThemeEvent extends ProfileEvent {
  final AppThemeMode themeMode;

  const ChangeThemeEvent({required this.themeMode});

  @override
  List<Object> get props => [themeMode];
}

class LogoutEvent extends ProfileEvent {
  const LogoutEvent();
}
