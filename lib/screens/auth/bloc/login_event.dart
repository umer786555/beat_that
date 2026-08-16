import 'package:equatable/equatable.dart';

/// Base event class for login bloc
abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when email field changes
class EmailChanged extends LoginEvent {
  final String email;

  const EmailChanged({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Event triggered when password field changes
class PasswordChanged extends LoginEvent {
  final String password;

  const PasswordChanged({required this.password});

  @override
  List<Object?> get props => [password];
}

/// Event triggered when login form is submitted
class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Event triggered when Google sign-in is submitted
class GoogleLoginSubmitted extends LoginEvent {
  const GoogleLoginSubmitted();

  @override
  List<Object?> get props => [];
}

/// Event triggered when Apple sign-in is submitted
class AppleLoginSubmitted extends LoginEvent {
  const AppleLoginSubmitted();

  @override
  List<Object?> get props => [];
}

/// Event triggered when user wants to toggle password visibility
class PasswordVisibilityToggled extends LoginEvent {
  const PasswordVisibilityToggled();

  @override
  List<Object?> get props => [];
}

/// Event triggered when user taps forgot password link
class ForgotPasswordTapped extends LoginEvent {
  const ForgotPasswordTapped();

  @override
  List<Object?> get props => [];
}
