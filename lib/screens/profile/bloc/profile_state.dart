part of 'profile_bloc.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object> get props => [];
}

final class ProfileInitial extends ProfileState {}

final class ProfileLoaded extends ProfileState {
  final AppThemeMode currentTheme;

  const ProfileLoaded({required this.currentTheme});

  @override
  List<Object> get props => [currentTheme];

  ProfileLoaded copyWith({AppThemeMode? currentTheme}) {
    return ProfileLoaded(currentTheme: currentTheme ?? this.currentTheme);
  }
}

final class ProfileLoading extends ProfileState {}

final class ProfileError extends ProfileState {
  final String message;

  const ProfileError({required this.message});

  @override
  List<Object> get props => [message];
}
