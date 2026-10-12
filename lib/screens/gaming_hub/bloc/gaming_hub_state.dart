part of 'gaming_hub_bloc.dart';

sealed class GamingHubState extends Equatable {
  const GamingHubState();

  @override
  List<Object> get props => [];
}

final class GamingHubInitial extends GamingHubState {}

final class GamingHubLoading extends GamingHubState {}

final class GamingHubLoaded extends GamingHubState {
  final List<CategoryModel> games;

  const GamingHubLoaded(this.games);

  @override
  List<Object> get props => [games];
}

final class GamingHubError extends GamingHubState {
  final String message;
  const GamingHubError(this.message);

  @override
  List<Object> get props => [message];
}
