import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    on<GoogleSignupSubmitted>(_onGoogleSignupSubmitted);
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
  String _parseErrorMessage(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'google_canceled':
          return AppStrings.googleSignInCanceled;
        case 'google_interrupted':
          return AppStrings.googleSignInInterrupted;
        case 'google_clientConfigurationError':
        case 'google_providerConfigurationError':
        case 'google_id_token_missing':
          return AppStrings.googleSignInConfigurationIssue;
        case 'google_uiUnavailable':
          return AppStrings.googleSignInUiUnavailable;
        case 'google_userMismatch':
          return AppStrings.googleSignInUserMismatch;
        case 'google_config_missing':
          return AppStrings.googleSignInNotConfigured;
        case 'google_auth_unsupported':
        case 'google_platform_unsupported':
          return AppStrings.googleSignInNotSupported;
      }
    }

    final errorText = error.toString();
    // Check if it's a Supabase AuthException with error code
    if (errorText.contains('email_exists') ||
        errorText.contains('user_already_exists')) {
      return AppStrings.thisEmailIsAlreadyRegisteredPleaseSignInInstead;
    } else if (errorText.contains('User already registered')) {
      return AppStrings.thisEmailIsAlreadyRegisteredPleaseSignInInstead;
    } else if (errorText.contains('Error sending confirmation email')) {
      return AppStrings.confirmationEmailCouldNotBeSent;
    } else if (errorText.contains('Password')) {
      return AppStrings.passwordMustBeAtLeast6Characters;
    } else if (errorText.contains('Email')) {
      return AppStrings.pleaseEnterAValidEmailAddress;
    } else if (errorText.contains('Network')) {
      return AppStrings.networkErrorPleaseCheckYourConnection;
    } else if (errorText.contains('google_config_missing') ||
        errorText.contains('GOOGLE_WEB_CLIENT_ID')) {
      return AppStrings.googleSignInNotConfigured;
    } else if (errorText.contains('google_auth_unsupported') ||
        errorText.contains('google_platform_unsupported')) {
      return AppStrings.googleSignInNotSupported;
    } else if (errorText.toLowerCase().contains('canceled')) {
      return AppStrings.googleSignInCanceled;
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
    final email = _email.trim();
    final password = _password;
    final confirmPassword = _confirmPassword;

    // Validate email
    if (!_isValidEmail(email)) {
      emit(SignupFailure(error: AppStrings.pleaseEnterAValidEmail));
      return;
    }

    // Validate password
    if (!_isValidPassword(password)) {
      emit(SignupFailure(error: AppStrings.passwordMustBeAtLeast6Characters));
      return;
    }

    // Check if passwords match
    if (password.trim() != confirmPassword.trim()) {
      emit(SignupFailure(error: AppStrings.passwordsDoNotMatch));
      return;
    }

    try {
      // Emit loading state
      emit(const SignupLoading());

      // Attempt signup
      await authService.signup(
        email: email,
        password: password,
        userData: {
          'email': email,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      // Emit success state
      emit(const SignupSuccess());
    } catch (e) {
      // Emit failure state with error message
      final errorMessage = _parseErrorMessage(e);
      emit(SignupFailure(error: errorMessage));
    }
  }

  Future<void> _onGoogleSignupSubmitted(
    GoogleSignupSubmitted event,
    Emitter<SignupState> emit,
  ) async {
    try {
      emit(const SignupLoading());
      await authService.signInWithGoogle();
      emit(const SignupAuthenticatedSuccess());
    } catch (e) {
      final errorMessage = _parseErrorMessage(e);
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
