import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final preferencesService = locator<PreferencesService>();
  final supabaseService = locator<SupabaseService>();

  final authService = locator<AuthService>();
  HomeBloc() : super(HomeInitial()) {
    on<InitialEvent>(_onInitial);
    on<LogoutEvent>(_onLogout);
  }
  Future<void> _onInitial(InitialEvent event, Emitter<HomeState> emit) async {
    print('✓ HomeBloc InitialEvent triggered');
    await preferencesService.clearUserProfile();
    // Fetch from Supabase and save to local preferences
    final userProfile = await supabaseService.fetchUserPersonalProfile();

    if (userProfile != null) {
      // Save to preferences so it's available offline
      await preferencesService.saveUserProfile(userProfile);
      print('✓ User profile found and saved: ${userProfile.username}');
      emit(UserProfileLoaded(userProfile));
    } else {
      print('✗ No user profile found');
      emit(const NoUserProfile());
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<HomeState> emit) async {
    try {
      await preferencesService.clearUserProfile();
      await authService.logout();
      emit(const NoUserProfile());
    } catch (e) {
      print('Error logging out: $e');
    }
  }
}
