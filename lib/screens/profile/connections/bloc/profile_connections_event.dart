part of 'profile_connections_bloc.dart';

sealed class ProfileConnectionsEvent extends Equatable {
  const ProfileConnectionsEvent();

  @override
  List<Object> get props => [];
}

final class LoadProfileConnectionsEvent extends ProfileConnectionsEvent {
  const LoadProfileConnectionsEvent({this.forceRefresh = false});

  final bool forceRefresh;

  @override
  List<Object> get props => [forceRefresh];
}

final class LoadMoreProfileConnectionsEvent extends ProfileConnectionsEvent {
  const LoadMoreProfileConnectionsEvent();
}

final class SearchProfileConnectionsEvent extends ProfileConnectionsEvent {
  const SearchProfileConnectionsEvent({required this.query});

  final String query;

  @override
  List<Object> get props => [query];
}
