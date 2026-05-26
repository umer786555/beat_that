import 'package:flutter/material.dart';

/// Base event for SportsHubBloc
abstract class SportsHubEvent {
  const SportsHubEvent();
}

/// Event to fetch sports from Supabase
class FetchSportsEvent extends SportsHubEvent {
  final Locale? locale;

  const FetchSportsEvent({this.locale});
}

/// Event to retry fetching sports after error
class RetrySportsEvent extends SportsHubEvent {
  final Locale? locale;

  const RetrySportsEvent({this.locale});
}
