part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

final class InitialEvent extends HomeEvent {
  const InitialEvent();
}

final class LogoutEvent extends HomeEvent {
  const LogoutEvent();
}
