import 'package:equatable/equatable.dart';
import 'package:beat_that/constants/app_enums.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/service_locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc()
      : super(ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<ChangeThemeEvent>(_onChangeTheme);
    on<LogoutEvent>(_onLogout);
  }

  /// Load profile data
  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      // Initialize with default theme (dark)
      emit(const ProfileLoaded(currentTheme: AppThemeMode.dark));
    } catch (e) {
      emit(ProfileError(message: '${AppStrings.failedToLoadProfile}: $e'));
    }
  }

  /// Handle theme change - ProfileBloc only updates its own state
  /// UI layer (BlocListener) handles notifying ThemeBloc
  Future<void> _onChangeTheme(
    ChangeThemeEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit((state as ProfileLoaded).copyWith(currentTheme: event.themeMode));
    } catch (e) {
      emit(ProfileError(message: '${AppStrings.failedToChangeTheme}: $e'));
    }
  }

  /// Handle logout
  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      emit(ProfileLoading());
      final authService = getIt<AuthService>();
      await authService.logout();
    } catch (e) {
      emit(ProfileError(message: '${AppStrings.logoutFailed}: $e'));
    }
  }
}
