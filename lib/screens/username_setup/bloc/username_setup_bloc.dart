import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'username_setup_event.dart';
part 'username_setup_state.dart';
part 'username_setup_presentation_event.dart';

class UsernameSetupBloc extends Bloc<UsernameSetupEvent, UsernameSetupState>
    with
        BlocPresentationMixin<
          UsernameSetupState,
          UsernameSetupPresentationEvent
        > {
  final authService = locator<AuthService>();
  final preferencesService = locator<PreferencesService>();
  final supabaseService = locator<SupabaseService>();

  UsernameSetupBloc() : super(UsernameSetupInitial()) {
    on<SaveUsernameEvent>(_onSaveUsername);
  }

  Future<void> _onSaveUsername(
    SaveUsernameEvent event,
    Emitter<UsernameSetupState> emit,
  ) async {
    try {
      final requiresLegalAcceptance =
          !authService.hasAcceptedCurrentLegalVersion();

      if (requiresLegalAcceptance && !event.hasAcceptedLegal) {
        emitPresentation(
          const UsernameSetupErrorEvent(
            AppStrings.acceptTermsToCreateAccount,
          ),
        );
        return;
      }

      emit(UsernameSetupLoading());

      if (requiresLegalAcceptance) {
        await authService.recordLegalAcceptance();
      }

      // Step 1: Save username to Supabase
      // Service handles auth validation internally
      final supabaseResult = await supabaseService.saveUserPersonalProfile(
        event.username,
      );

      // Check if Supabase save was successful
      if (!supabaseResult['success']) {
        final errorMessage =
            supabaseResult['error'] ??
            'Sorry, something went wrong please try again.';
        emit(UsernameSetupInitial());
        emitPresentation(UsernameSetupErrorEvent(errorMessage));
        return;
      }

      // Step 2: Only if Supabase save was successful, save to preferences
      await preferencesService.updateUserProfileUsername(event.username);


      emit(UsernameSetupSuccess(event.username));

      emitPresentation(UsernameSetupSuccessEvent(event.username));
    } catch (e) {
      final errorMessage = 'Failed to save username: ${e.toString()}';
      emit(UsernameSetupInitial());
      emitPresentation(UsernameSetupErrorEvent(errorMessage));
    }
  }
}
