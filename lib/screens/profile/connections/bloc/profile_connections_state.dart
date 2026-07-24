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
  const ProfileConnectionsLoaded({
    required this.users,
    this.hasMoreContent = true,
    this.isLoadingMore = false,
    this.searchQuery = '',
  });

  final List<UserProfileSummary> users;
  final bool hasMoreContent;
  final bool isLoadingMore;
  final String searchQuery;

  @override
  List<Object> get props => [users, hasMoreContent, isLoadingMore, searchQuery];
}

final class ProfileConnectionsError extends ProfileConnectionsState {
  const ProfileConnectionsError({required this.message});

  final String message;

  @override
  List<Object> get props => [message];
}
