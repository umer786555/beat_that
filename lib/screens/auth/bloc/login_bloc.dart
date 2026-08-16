import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/constants/app_strings.dart';
import 'login_event.dart';
import 'login_state.dart';

/// Bloc for managing login screen state and logic
///
/// Handles:
/// - Email and password input
/// - Form validation
/// - Login submission
/// - Password visibility toggle
/// - Error handling
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  late final AuthService authService;

  // Current form state
  String _email = '';
  String _password = '';
  bool _obscurePassword = true;

  LoginBloc() : super(const LoginInitial()) {
    // Get AuthService from service locator
    authService = locator<AuthService>();
    // Register event handlers
    on<EmailChanged>(_onEmailChanged);
    on<PasswordChanged>(_onPasswordChanged);
    on<PasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<GoogleLoginSubmitted>(_onGoogleLoginSubmitted);
    on<AppleLoginSubmitted>(_onAppleLoginSubmitted);
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim());
  }

  /// Validate password (minimum 6 characters)
  bool _isValidPassword(String password) {
    return password.trim().length >= 6;
  }

  /// Parse error message to be user-friendly
  String _parseErrorMessage(Object error) {
    if (error is AuthException) {
      final normalizedDetails = '${error.code ?? ''} ${error.message}'
          .toLowerCase();

      switch (error.code) {
        case 'apple_canceled':
          return AppStrings.appleSignInCanceled;
        case 'apple_failed':
          if (normalizedDetails.contains('provider') &&
              normalizedDetails.contains('enable')) {
            return AppStrings.appleSignInNotConfigured;
          }
          if (normalizedDetails.contains('audience') ||
              normalizedDetails.contains('client id') ||
              normalizedDetails.contains('client_id') ||
              normalizedDetails.contains('bundle id')) {
            return AppStrings.appleSignInConfigurationIssue;
          }
          if (normalizedDetails.contains('nonce')) {
            return AppStrings.appleSignInConfigurationIssue;
          }
          return AppStrings.appleSignInFailedPleaseTryAgain;
        case 'apple_not_available':
        case 'apple_platform_unsupported':
          return AppStrings.appleSignInNotSupported;
        case 'apple_id_token_missing':
        case 'apple_invalidResponse':
        case 'apple_notHandled':
        case 'apple_notInteractive':
        case 'apple_unknown':
          return AppStrings.appleSignInFailedPleaseTryAgain;
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
    if (errorText.contains('Invalid login credentials')) {
      return AppStrings.invalidEmailOrPassword;
    } else if (errorText.contains('Email not confirmed')) {
      return AppStrings.pleaseConfirmYourEmailBeforeLoggingIn;
    } else if (errorText.contains('User not found')) {
      return AppStrings.userNotFoundPleaseSignUpFirst;
    } else if (errorText.contains('Network')) {
      return AppStrings.networkErrorPleaseCheckYourConnection;
    } else if (errorText.contains('google_config_missing') ||
        errorText.contains('GOOGLE_WEB_CLIENT_ID')) {
      return AppStrings.googleSignInNotConfigured;
    } else if (errorText.contains('google_auth_unsupported') ||
        errorText.contains('google_platform_unsupported')) {
      return AppStrings.googleSignInNotSupported;
    } else if (errorText.contains('apple_not_available') ||
        errorText.contains('apple_platform_unsupported')) {
      return AppStrings.appleSignInNotSupported;
    } else if (errorText.toLowerCase().contains('canceled')) {
      return AppStrings.googleSignInCanceled;
    }
    return AppStrings.loginFailedPleaseTryAgain;
  }

  /// Handle email input change
  void _onEmailChanged(EmailChanged event, Emitter<LoginState> emit) {
    _email = event.email;
    _updateFormState(emit);
  }

  /// Handle password input change
  void _onPasswordChanged(PasswordChanged event, Emitter<LoginState> emit) {
    _password = event.password;
    _updateFormState(emit);
  }

  /// Handle password visibility toggle
  void _onPasswordVisibilityToggled(
    PasswordVisibilityToggled event,
    Emitter<LoginState> emit,
  ) {
    _obscurePassword = !_obscurePassword;
    _updateFormState(emit);
  }

  /// Handle login form submission
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    // Validate form
    if (!_isValidEmail(event.email)) {
      emit(LoginFailure(error: AppStrings.pleaseEnterAValidEmail));
      return;
    }

    if (!_isValidPassword(event.password)) {
      emit(LoginFailure(error: AppStrings.passwordMustBeAtLeast6Characters));
      return;
    }

    try {
      // Emit loading state
      emit(const LoginLoading());

      // Attempt login
      await authService.login(
        email: event.email.trim(),
        password: event.password.trim(),
      );

      // Emit success state
      emit(const LoginSuccess());
    } catch (e) {
      // Emit failure state with error message
      final errorMessage = _parseErrorMessage(e);
      emit(LoginFailure(error: errorMessage));
    }
  }

  Future<void> _onGoogleLoginSubmitted(
    GoogleLoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      emit(const LoginLoading());
      await authService.signInWithGoogle();
      emit(const LoginSuccess());
    } catch (e) {
      final errorMessage = _parseErrorMessage(e);
      emit(LoginFailure(error: errorMessage));
    }
  }

  Future<void> _onAppleLoginSubmitted(
    AppleLoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    try {
      emit(const LoginLoading());
      await authService.signInWithApple();
      emit(const LoginSuccess());
    } catch (e) {
      debugPrint('Apple login failed: $e');
      final errorMessage = _parseErrorMessage(e);
      emit(LoginFailure(error: errorMessage));
    }
  }

  /// Update form state with current values
  void _updateFormState(Emitter<LoginState> emit) {
    final isEmailValid = _isValidEmail(_email);
    final isPasswordValid = _isValidPassword(_password);

    emit(
      LoginFormUpdated(
        email: _email,
        password: _password,
        obscurePassword: _obscurePassword,
        isEmailValid: isEmailValid,
        isPasswordValid: isPasswordValid,
      ),
    );
  }

  /// Get current email
  // String get email => _email;

  /// Get current password
  // String get password => _password;

  /// Get password visibility state
  // bool get obscurePassword => _obscurePassword;
}
