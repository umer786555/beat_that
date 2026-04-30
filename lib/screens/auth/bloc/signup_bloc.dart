import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'signup_event.dart';
import 'signup_state.dart';

/// Bloc for managing signup screen state and logic
///
/// Handles:
/// - Email and password input
/// - Password confirmation matching
/// - Form validation
/// - Signup submission
/// - Password visibility toggle
/// - Error handling
class SignupBloc extends Bloc<SignupEvent, SignupState> {
  late final AuthService authService;

  // Current form state
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  SignupBloc() : super(const SignupInitial()) {
    // Get AuthService from service locator
    authService = locator<AuthService>();
    // Register event handlers
    on<EmailChanged>(_onEmailChanged);
    on<PasswordChanged>(_onPasswordChanged);
    on<ConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<PasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<ConfirmPasswordVisibilityToggled>(_onConfirmPasswordVisibilityToggled);
    on<SignupSubmitted>(_onSignupSubmitted);
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim());
  }

  /// Validate password (minimum 6 characters)
  bool _isValidPassword(String password) {
    return password.trim().length >= 6;
  }

  /// Check if passwords match
  bool _passwordsMatch(String password, String confirmPassword) {
    return password.trim() == confirmPassword.trim() &&
        password.trim().isNotEmpty;
  }

  /// Parse error message to be user-friendly
  String _parseErrorMessage(String error) {
    // Check if it's a Supabase AuthException with error code
    if (error.contains('email_exists') ||
        error.contains('user_already_exists')) {
      return AppStrings.thisEmailIsAlreadyRegisteredPleaseSignInInstead;
    } else if (error.contains('User already registered')) {
      return AppStrings.thisEmailIsAlreadyRegisteredPleaseSignInInstead;
    } else if (error.contains('Password')) {
      return AppStrings.passwordMustBeAtLeast6Characters;
    } else if (error.contains('Email')) {
      return AppStrings.pleaseEnterAValidEmailAddress;
    } else if (error.contains('Network')) {
      return AppStrings.networkErrorPleaseCheckYourConnection;
    }
    return AppStrings.signupFailedPleaseTryAgain;
  }

  /// Handle email input change
  Future<void> _onEmailChanged(
    EmailChanged event,
    Emitter<SignupState> emit,
  ) async {
    _email = event.email;
    _updateFormState(emit);
  }

  /// Handle password input change
  Future<void> _onPasswordChanged(
    PasswordChanged event,
    Emitter<SignupState> emit,
  ) async {
    _password = event.password;
    _updateFormState(emit);
  }

  /// Handle confirm password input change
  Future<void> _onConfirmPasswordChanged(
    ConfirmPasswordChanged event,
    Emitter<SignupState> emit,
  ) async {
    _confirmPassword = event.confirmPassword;
    _updateFormState(emit);
  }

  /// Handle password visibility toggle
  Future<void> _onPasswordVisibilityToggled(
    PasswordVisibilityToggled event,
    Emitter<SignupState> emit,
  ) async {
    _obscurePassword = !_obscurePassword;
    _updateFormState(emit);
  }

  /// Handle confirm password visibility toggle
  Future<void> _onConfirmPasswordVisibilityToggled(
    ConfirmPasswordVisibilityToggled event,
    Emitter<SignupState> emit,
  ) async {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    _updateFormState(emit);
  }

  /// Handle signup form submission
  Future<void> _onSignupSubmitted(
    SignupSubmitted event,
    Emitter<SignupState> emit,
  ) async {
    // Validate email
    if (!_isValidEmail(event.email)) {
      emit(SignupFailure(error: AppStrings.pleaseEnterAValidEmail));
      return;
    }

    // Validate password
    if (!_isValidPassword(event.password)) {
      emit(SignupFailure(error: AppStrings.passwordMustBeAtLeast6Characters));
      return;
    }

    // Check if passwords match
    if (event.password.trim() != event.confirmPassword.trim()) {
      emit(SignupFailure(error: AppStrings.passwordsDoNotMatch));
      return;
    }

    try {
      // Emit loading state
      emit(const SignupLoading());

      // Attempt signup
      await authService.signup(
        email: event.email.trim(),
        password: event.password,
        userData: {
          'email': event.email.trim(),
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      // Emit success state
      emit(const SignupSuccess());
    } catch (e) {
      // Emit failure state with error message
      final errorMessage = _parseErrorMessage(e.toString());
      emit(SignupFailure(error: errorMessage));
    }
  }

  /// Update form state with current values
  void _updateFormState(Emitter<SignupState> emit) {
    final isEmailValid = _isValidEmail(_email);
    final isPasswordValid = _isValidPassword(_password);
    final passwordsMatch = _passwordsMatch(_password, _confirmPassword);

    emit(
      SignupFormUpdated(
        email: _email,
        password: _password,
        confirmPassword: _confirmPassword,
        obscurePassword: _obscurePassword,
        obscureConfirmPassword: _obscureConfirmPassword,
        isEmailValid: isEmailValid,
        isPasswordValid: isPasswordValid,
        passwordsMatch: passwordsMatch,
      ),
    );
  }

  // /// Get current email
  // String get email => _email;

  // /// Get current password
  // String get password => _password;

  // /// Get current confirm password
  // String get confirmPassword => _confirmPassword;

  // /// Get password visibility state
  // bool get obscurePassword => _obscurePassword;

  // /// Get confirm password visibility state
  // bool get obscureConfirmPassword => _obscureConfirmPassword;
}
