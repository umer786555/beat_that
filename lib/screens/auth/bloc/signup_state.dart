import 'package:equatable/equatable.dart';

/// Base state class for signup bloc
abstract class SignupState extends Equatable {
  const SignupState();

  @override
  List<Object?> get props => [];
}

/// Initial state when the signup screen is first loaded
class SignupInitial extends SignupState {
  const SignupInitial();
}

/// State when signup form is being submitted
class SignupLoading extends SignupState {
  const SignupLoading();
}

/// State when signup is successful
class SignupSuccess extends SignupState {
  const SignupSuccess();
}

/// State when signup fails
class SignupFailure extends SignupState {
  final String error;

  const SignupFailure({required this.error});

  @override
  List<Object?> get props => [error];

  /// Create a copy of this state with some fields replaced by new values
  SignupFailure copyWith({
    String? error,
  }) {
    return SignupFailure(
      error: error ?? this.error,
    );
  }
}

/// State for form validation and UI updates
class SignupFormUpdated extends SignupState {
  final String email;
  final String password;
  final String confirmPassword;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isEmailValid;
  final bool isPasswordValid;
  final bool passwordsMatch;

  const SignupFormUpdated({
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    this.isEmailValid = false,
    this.isPasswordValid = false,
    this.passwordsMatch = false,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    confirmPassword,
    obscurePassword,
    obscureConfirmPassword,
    isEmailValid,
    isPasswordValid,
    passwordsMatch,
  ];

  /// Create a copy of this state with some fields replaced by new values
  SignupFormUpdated copyWith({
    String? email,
    String? password,
    String? confirmPassword,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    bool? isEmailValid,
    bool? isPasswordValid,
    bool? passwordsMatch,
  }) {
    return SignupFormUpdated(
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword: obscureConfirmPassword ?? this.obscureConfirmPassword,
      isEmailValid: isEmailValid ?? this.isEmailValid,
      isPasswordValid: isPasswordValid ?? this.isPasswordValid,
      passwordsMatch: passwordsMatch ?? this.passwordsMatch,
    );
  }
}
