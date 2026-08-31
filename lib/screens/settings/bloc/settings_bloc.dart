import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
    on<LogoutRequested>(_onLogoutRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
  }

  final PreferencesService _preferencesService = locator<PreferencesService>();
  final AuthService _authService = locator<AuthService>();
  final SupabaseService _supabaseService = locator<SupabaseService>();

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: SettingsStatus.loggingOut, clearError: true));

    try {
      await _preferencesService.clearUserProfile();
      await _preferencesService.clearEngagement();
      await _authService.logout();

      emit(state.copyWith(status: SettingsStatus.loggedOut, clearError: true));
    } catch (e) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          errorMessage: '${AppStrings.logoutFailed}: $e',
        ),
      );
    }
  }

  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(
      state.copyWith(status: SettingsStatus.deletingAccount, clearError: true),
    );

    try {
      final result = await _supabaseService.deleteCurrentUserViaEdgeFunction();
      if (result['success'] != true) {
        throw Exception(result['error'] ?? AppStrings.deleteAccountFailed);
      }

      await _preferencesService.clearUserProfile();
      await _preferencesService.clearEngagement();
      await _authService.logout();

      emit(
        state.copyWith(status: SettingsStatus.deletedAccount, clearError: true),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          errorMessage: '${AppStrings.deleteAccountFailed}: $e',
        ),
      );
    }
  }
}
