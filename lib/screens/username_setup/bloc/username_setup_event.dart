part of 'username_setup_bloc.dart';

sealed class UsernameSetupEvent extends Equatable {
  const UsernameSetupEvent();

  @override
  List<Object> get props => [];
}

final class SaveUsernameEvent extends UsernameSetupEvent {
  final String username;

  const SaveUsernameEvent(this.username);

  @override
  List<Object> get props => [username];
}
