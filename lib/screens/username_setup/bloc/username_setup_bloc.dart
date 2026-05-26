import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
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
      emit(UsernameSetupLoading());

      // Step 1: Save username to Supabase
      final supabaseResult = await supabaseService.saveUserPersonalProfile(
        UserPersonalProfile(username: event.username),
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
      await preferencesService.saveUserProfile(
        UserPersonalProfile(username: event.username),
      );

      print('✓ Username saved successfully: ${event.username}');
      print('✓ Emitting UsernameSetupSuccess state');
      emit(UsernameSetupSuccess(event.username));

      print('✓ Emitting UsernameSetupSuccessEvent presentation');
      emitPresentation(UsernameSetupSuccessEvent(event.username));
    } catch (e) {
      print('✗ Error saving username: $e');
      final errorMessage = 'Failed to save username: ${e.toString()}';
      emit(UsernameSetupInitial());
      emitPresentation(UsernameSetupErrorEvent(errorMessage));
    }
  }
}
