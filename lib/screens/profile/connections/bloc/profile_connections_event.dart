part of 'profile_connections_bloc.dart';

sealed class ProfileConnectionsEvent extends Equatable {
  const ProfileConnectionsEvent();

  @override
  List<Object> get props => [];
}

final class LoadProfileConnectionsEvent extends ProfileConnectionsEvent {
  const LoadProfileConnectionsEvent();
}
