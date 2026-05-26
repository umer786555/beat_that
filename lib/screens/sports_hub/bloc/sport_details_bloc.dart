import 'package:beat_that/models/sport.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'sport_details_event.dart';
part 'sport_details_state.dart';

class SportDetailsBloc extends Bloc<SportDetailsEvent, SportDetailsState> {
  SportDetailsBloc() : super(const SportDetailsInitial()) {
    // Register event handlers
    on<LoadSportDetailsEvent>(_onLoadSportDetails);
  }

  /// Load sport details - data already fetched from SportsHubBloc
  Future<void> _onLoadSportDetails(
    LoadSportDetailsEvent event,
    Emitter<SportDetailsState> emit,
  ) async {
    try {
      emit(const SportDetailsLoading());
      // Simulate a small delay for smooth UX
      await Future.delayed(const Duration(milliseconds: 300));
      // Sport already has all subcategories from SportsHubBloc, just emit it
      emit(SportDetailsLoaded(sport: event.sport));
    } catch (e) {
      emit(SportDetailsError(message: 'Failed to load sport details'));
    }
  }

}