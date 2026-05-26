import 'package:beat_that/models/sport.dart';

/// Base state for SportsHubBloc
abstract class SportsHubState {
  const SportsHubState();
}

/// Initial state when the bloc is created
class SportsHubInitial extends SportsHubState {
  const SportsHubInitial();
}

/// Loading state while fetching sports from Supabase
class SportsHubLoading extends SportsHubState {
  const SportsHubLoading();
}

/// Loaded state with successfully fetched sports
class SportsHubLoaded extends SportsHubState {
  final List<Sport> sports;

  const SportsHubLoaded({required this.sports});
}

/// Error state when fetching sports fails
class SportsHubError extends SportsHubState {
  final String message;

  const SportsHubError({required this.message});
}
