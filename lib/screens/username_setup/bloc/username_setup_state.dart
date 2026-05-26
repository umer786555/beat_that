part of 'username_setup_bloc.dart';

sealed class UsernameSetupState extends Equatable {
  const UsernameSetupState();

  @override
  List<Object> get props => [];
}

final class UsernameSetupInitial extends UsernameSetupState {}

final class UsernameSetupLoading extends UsernameSetupState {}


final class UsernameSetupSuccess extends UsernameSetupState {
  final String username;

  const UsernameSetupSuccess(this.username);

  @override
  List<Object> get props => [username];
}
