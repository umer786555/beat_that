import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/models/sport.dart';
import 'package:beat_that/models/sport_subcategory.dart';
import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/service_locator.dart';
import 'sports_hub_event.dart';
import 'sports_hub_state.dart';

class SportsHubBloc extends Bloc<SportsHubEvent, SportsHubState> {
  // Service to fetch sport data from Supabase
  final SupabaseService _supabaseService = locator<SupabaseService>();

  SportsHubBloc() : super(const SportsHubInitial()) {
    // Register event handlers
    on<FetchSportsEvent>(_onFetchSports);
    on<RetrySportsEvent>(_onRetrySports);
  }

  /// Handle FetchSportsEvent - fetch sports from Supabase and apply locale ordering
  Future<void> _onFetchSports(
    FetchSportsEvent event,
    Emitter<SportsHubState> emit,
  ) async {
    // Emit loading state to show loading UI
    emit(const SportsHubLoading());

    try {
      // Step 1: Fetch all sports and their subcategories from Supabase in one call
      // Returns Map<String, List<SportSubcategory>> where key is sport_id and value is list of subcategory objects
      // Example: {'soccer': [SportSubcategory(id:1, name:'Penalty Kick'), ...], 'basketball': [...]}
      final sportMap = await _supabaseService.getAllSportsWithSubcategories();

      // Handle empty data case
      if (sportMap.isEmpty) {
        emit(const SportsHubError(message: 'No sports found in the database'));
        return;
      }

      // Step 2: Get the correct ordering based on user's locale
      // Different regions have different sports popularity (e.g., cricket in India, football in US)
      final orderedSportIds = _getOrderedSportIds(event.locale);

      // Step 3: Build Sport objects in the correct regional order
      // - Filter to only sports that exist in our database
      // - Build each sport with metadata (icon, name) and fetched subcategories
      // - Remove any nulls and convert to list
      final sports = orderedSportIds
          .where((id) => sportMap.containsKey(id))
          .map((id) => _buildSport(id, sportMap[id]!))
          .whereType<Sport>()
          .toList();

      // Step 4: Emit loaded state with ordered sports
      emit(SportsHubLoaded(sports: sports));
    } catch (e) {
      // Handle any errors during fetch
      emit(SportsHubError(message: 'Failed to fetch sports: $e'));
    }
  }

  /// Get ordered sport IDs based on locale with fallback chain
  /// 
  /// Priority order:
  /// 1. Full locale match (language_COUNTRY) - e.g., 'en_IN' for India
  /// 2. Language-only match - e.g., 'en' for any English region
  /// 3. Default English ordering - fallback for unknown locales
  /// 
  /// Example:
  /// - User in India (Locale('en', 'IN')) → tries 'en_IN' → if found, return cricket-first order
  /// - User in France (Locale('fr', 'FR')) → tries 'fr_FR' → if not found, tries 'fr' → if found, return soccer-first order
  /// - Unknown locale → return English default ordering
  List<String> _getOrderedSportIds(Locale? locale) {
    if (locale == null) return sportOrderByLocale['en']!;

    // Construct full locale string (e.g., 'en_IN', 'de_DE')
    final fullLocale = '${locale.languageCode}_${locale.countryCode}';
    
    // Try full match first, then language-only, then default
    return sportOrderByLocale[fullLocale] ??
        sportOrderByLocale[locale.languageCode] ??
        sportOrderByLocale['en']!;
  }

  /// Build a Sport object from a sport ID and its subcategories
  /// 
  /// Uses helper functions to infer the display name and icon from the sport ID
  /// Subcategories are fetched from Supabase database
  Sport? _buildSport(String sportId, List<SportSubcategory> subcategories) {
    return Sport(
      id: sportId,
      name: sportId,
      displayName: getDisplayNameForSport(sportId),
      icon: getIconForSport(sportId),
      subcategories: subcategories, // From Supabase
    );
  }

  /// Handle RetrySportsEvent - retry fetching after an error
  /// Simply re-triggers the fetch with the same locale
  Future<void> _onRetrySports(
    RetrySportsEvent event,
    Emitter<SportsHubState> emit,
  ) async {
    await _onFetchSports(
      FetchSportsEvent(locale: event.locale),
      emit,
    );
  }
}
