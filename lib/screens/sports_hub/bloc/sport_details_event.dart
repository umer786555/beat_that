part of 'sport_details_bloc.dart';

abstract class SportDetailsEvent extends Equatable {
  const SportDetailsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSportDetailsEvent extends SportDetailsEvent {
  final Sport sport;

  const LoadSportDetailsEvent({required this.sport});

  @override
  List<Object?> get props => [sport];
}

