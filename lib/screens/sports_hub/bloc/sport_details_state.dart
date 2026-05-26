part of 'sport_details_bloc.dart';

abstract class SportDetailsState extends Equatable {
  const SportDetailsState();

  @override
  List<Object?> get props => [];
}

class SportDetailsInitial extends SportDetailsState {
  const SportDetailsInitial();
}

class SportDetailsLoading extends SportDetailsState {
  const SportDetailsLoading();
}

class SportDetailsLoaded extends SportDetailsState {
  final Sport sport;

  const SportDetailsLoaded({required this.sport});

  @override
  List<Object?> get props => [sport];
}

class SportDetailsError extends SportDetailsState {
  final String message;

  const SportDetailsError({required this.message});

  @override
  List<Object?> get props => [message];
}
