import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/constants/app_strings.dart';
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

  Future<void> _onFetchSports(
    FetchSportsEvent event,
    Emitter<SportsHubState> emit,
  ) async {
    // Emit loading state to show loading UI
    emit(const SportsHubLoading());

    try {
      // Step 1: Fetch only sports data (small payload) from new sports table
      // Returns List<Category> with empty subcategories
      final sports = await _supabaseService.getAllSports();

      // Step 2: Get the correct ordering based on user's locale
      // Different regions have different sports popularity (e.g., cricket in India, football in US)
      final orderedSportIds = getOrderedSportIdsForLocale(event.locale);
      final orderIndexBySportName = <String, int>{
        for (var index = 0; index < orderedSportIds.length; index++)
          orderedSportIds[index]: index,
      };

      // Step 3: Sort fetched sports according to locale preferences.
      // Backend sports not present in the hard-coded order list are appended
      // instead of being dropped from the UI.
      // "Other Games" is always placed at the bottom.
      final sportsWithoutOther = <CategoryModel>[];
      CategoryModel? otherGames;

      for (final sport in sports) {
        if (sport.displayName.toLowerCase() == 'other games') {
          otherGames = sport;
        } else {
          sportsWithoutOther.add(sport);
        }
      }

      sportsWithoutOther.sort((left, right) {
        final leftIndex =
            orderIndexBySportName[left.name] ?? orderedSportIds.length;
        final rightIndex =
            orderIndexBySportName[right.name] ?? orderedSportIds.length;

        if (leftIndex != rightIndex) {
          return leftIndex.compareTo(rightIndex);
        }

        return left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        );
      });

      // Add "Other Games" at the end if it exists
      if (otherGames != null) {
        sportsWithoutOther.add(otherGames);
      }

      final orderedSports = sportsWithoutOther;

      // Step 4: Emit loaded state with sports (subcategories will load on selection)
      emit(SportsHubLoaded(sports: orderedSports));
    } catch (e) {
      // Handle any errors during fetch
      emit(SportsHubError(message:  AppStrings.somethingWentWrongPleaseTryAgain));
    }
  }

  /// Handle RetrySportsEvent - retry fetching after an error
  /// Simply re-triggers the fetch with the same locale
  Future<void> _onRetrySports(
    RetrySportsEvent event,
    Emitter<SportsHubState> emit,
  ) async {
    await _onFetchSports(FetchSportsEvent(locale: event.locale), emit);
  }
}
