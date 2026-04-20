import 'package:equatable/equatable.dart';

/// Base state class for login bloc
abstract class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

/// Initial state when the login screen is first loaded
class LoginInitial extends LoginState {
  const LoginInitial();
}

/// State when login form is being submitted
class LoginLoading extends LoginState {
  const LoginLoading();
}

/// State when login is successful
class LoginSuccess extends LoginState {
  const LoginSuccess();
}

/// State when login fails
class LoginFailure extends LoginState {
  final String error;

  const LoginFailure({required this.error});

  @override
  List<Object?> get props => [error];

  /// Create a copy of this state with some fields replaced by new values
  LoginFailure copyWith({
    String? error,
  }) {
    return LoginFailure(
      error: error ?? this.error,
    );
  }
}

/// State for form validation and UI updates
class LoginFormUpdated extends LoginState {
  final String email;
  final String password;
  final bool obscurePassword;
  final bool isEmailValid;
  final bool isPasswordValid;

  const LoginFormUpdated({
    required this.email,
    required this.password,
    required this.obscurePassword,
    this.isEmailValid = false,
    this.isPasswordValid = false,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    obscurePassword,
    isEmailValid,
    isPasswordValid,
  ];

  /// Create a copy of this state with some fields replaced by new values
  LoginFormUpdated copyWith({
    String? email,
    String? password,
    bool? obscurePassword,
    bool? isEmailValid,
    bool? isPasswordValid,
  }) {
    return LoginFormUpdated(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isEmailValid: isEmailValid ?? this.isEmailValid,
      isPasswordValid: isPasswordValid ?? this.isPasswordValid,
    );
  }
}
