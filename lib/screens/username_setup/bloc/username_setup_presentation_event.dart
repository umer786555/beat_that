part of 'username_setup_bloc.dart';


sealed class UsernameSetupPresentationEvent extends Equatable {
  const UsernameSetupPresentationEvent();

  @override
  List<Object> get props => [];
}

final class UsernameSetupErrorEvent extends UsernameSetupPresentationEvent {
  final String message;

  const UsernameSetupErrorEvent(this.message);

  @override
  List<Object> get props => [message];
}

final class UsernameSetupSuccessEvent extends UsernameSetupPresentationEvent {
  final String username;

  const UsernameSetupSuccessEvent(this.username);

  @override
  List<Object> get props => [username];
}
