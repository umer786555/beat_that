import 'package:beat_that/constants/app_strings.dart';
import 'package:beat_that/models/category.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'gaming_hub_event.dart';
part 'gaming_hub_state.dart';

class GamingHubBloc extends Bloc<GamingHubEvent, GamingHubState> {
  final SupabaseService _supabaseService = locator<SupabaseService>();

  GamingHubBloc() : super(GamingHubInitial()) {
    on<LoadGamingHubEvent>((event, emit) async {
      emit(GamingHubLoading());
      try {
        final games = await _supabaseService.fetchGames();

        // Sort games alphabetically with "Other Games" at the bottom
        final sortedGames = _sortGamesWithOtherLast(games);

        emit(GamingHubLoaded(sortedGames));
      } catch (error, stackTrace) {
        addError(error, stackTrace);
        emit(const GamingHubError(AppStrings.somethingWentWrongPleaseTryAgain));
      }
    });
  }

  /// Sort games alphabetically by displayName, with "Other Games" always at the bottom
  List<CategoryModel> _sortGamesWithOtherLast(List<CategoryModel> games) {
    final notOther = <CategoryModel>[];
    CategoryModel? otherGames;

    for (final game in games) {
      if (game.displayName.toLowerCase() == 'other games') {
        otherGames = game;
      } else {
        notOther.add(game);
      }
    }

    // Sort alphabetically by displayName
    notOther.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    // Add "Other Games" at the end if it exists
    if (otherGames != null) {
      notOther.add(otherGames);
    }

    return notOther;
  }
}
