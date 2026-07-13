part of 'profile_connections_bloc.dart';

sealed class ProfileConnectionsState extends Equatable {
  const ProfileConnectionsState();

  @override
  List<Object> get props => [];
}

final class ProfileConnectionsInitial extends ProfileConnectionsState {
  const ProfileConnectionsInitial();
}

final class ProfileConnectionsLoading extends ProfileConnectionsState {
  const ProfileConnectionsLoading();
}

final class ProfileConnectionsLoaded extends ProfileConnectionsState {
  const ProfileConnectionsLoaded({required this.users});

  final List<UserProfileSummary> users;

  @override
  List<Object> get props => [users];
}

final class ProfileConnectionsError extends ProfileConnectionsState {
  const ProfileConnectionsError({required this.message});

  final String message;

  @override
  List<Object> get props => [message];
}
