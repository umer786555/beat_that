import 'package:equatable/equatable.dart';

/// Base event class for signup bloc
abstract class SignupEvent extends Equatable {
  const SignupEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when email field changes
class EmailChanged extends SignupEvent {
  final String email;

  const EmailChanged({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Event triggered when password field changes
class PasswordChanged extends SignupEvent {
  final String password;

  const PasswordChanged({required this.password});

  @override
  List<Object?> get props => [password];
}

/// Event triggered when confirm password field changes
class ConfirmPasswordChanged extends SignupEvent {
  final String confirmPassword;

  const ConfirmPasswordChanged({required this.confirmPassword});

  @override
  List<Object?> get props => [confirmPassword];
}

/// Event triggered when signup form is submitted
class SignupSubmitted extends SignupEvent {
  final String email;
  final String password;
  final String confirmPassword;

  const SignupSubmitted({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [email, password, confirmPassword];
}

/// Event triggered when user wants to toggle password visibility
class PasswordVisibilityToggled extends SignupEvent {
  const PasswordVisibilityToggled();

  @override
  List<Object?> get props => [];
}

/// Event triggered when user wants to toggle confirm password visibility
class ConfirmPasswordVisibilityToggled extends SignupEvent {
  const ConfirmPasswordVisibilityToggled();

  @override
  List<Object?> get props => [];
}
