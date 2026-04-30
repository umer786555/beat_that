import 'package:flutter_bloc/flutter_bloc.dart';
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
  String _parseErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return AppStrings.invalidEmailOrPassword;
    } else if (error.contains('Email not confirmed')) {
      return AppStrings.pleaseConfirmYourEmailBeforeLoggingIn;
    } else if (error.contains('User not found')) {
      return AppStrings.userNotFoundPleaseSignUpFirst;
    } else if (error.contains('Network')) {
      return AppStrings.networkErrorPleaseCheckYourConnection;
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
      final errorMessage = _parseErrorMessage(e.toString());
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
