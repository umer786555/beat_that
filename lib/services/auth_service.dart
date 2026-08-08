import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication service for managing user authentication with Supabase
///
/// Provides methods for:
/// - User login with email and password
/// - User registration/signup
/// - User logout
/// - Check if user is logged in
/// - Get current user information
/// - Get current session
/// - Listen to authentication state changes
class AuthService {
  static const String authCallbackScheme = 'com.theblackappcompany.beatthat';
  static const String authCallbackHost = 'login-callback';
  static const String authCallbackUrl =
      '$authCallbackScheme://$authCallbackHost';

  final SupabaseClient _supabase;

  AuthService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Sign up a new user with email and password
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password (minimum 6 characters recommended)
  /// - [userData]: Optional user metadata to store with the account
  ///
  /// Returns:
  /// - [AuthResponse] containing the user and session data
  ///
  /// Throws:
  /// - [AuthException] if signup fails
  Future<AuthResponse> signup({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
    String? emailRedirectTo,
  }) async {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo ?? authCallbackUrl,
      data: userData,
    );
  }

  /// Sign in an existing user with email and password
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password
  ///
  /// Returns:
  /// - [AuthResponse] containing the user and session data
  ///
  /// Throws:
  /// - [AuthException] if login fails (invalid credentials, etc.)
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out the current user
  ///
  /// Clears the session and removes authentication credentials
  ///
  /// Returns: void
  ///
  /// Throws:
  /// - [AuthException] if logout fails
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a user is currently logged in
  ///
  /// Returns:
  /// - [bool]: true if user is logged in, false otherwise
  bool isLoggedIn() {
    final session = _supabase.auth.currentSession;
    return session != null && !session.isExpired;
  }

  /// Get the currently logged-in user
  ///
  /// Returns:
  /// - [User?]: The current user if logged in, null otherwise
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Get the current authentication session
  ///
  /// Returns:
  /// - [Session?]: The current session if exists, null otherwise
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  /// Get the current user's ID
  ///
  /// Returns:
  /// - [String?]: The user ID if logged in, null otherwise
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Get the current user's email
  ///
  /// Returns:
  /// - [String?]: The user email if logged in, null otherwise
  String? getCurrentUserEmail() {
    return _supabase.auth.currentUser?.email;
  }

  /// Update the current user's information
  ///
  /// Parameters:
  /// - [attributes]: UserAttributes object containing fields to update
  ///   - email: Update user's email
  ///   - password: Update user's password
  ///   - data: Update user's metadata
  ///
  /// Returns:
  /// - [UserResponse] containing the updated user
  ///
  /// Throws:
  /// - [AuthException] if update fails
  Future<UserResponse> updateUser(UserAttributes attributes) async {
    try {
      final response = await _supabase.auth.updateUser(attributes);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh the current session
  ///
  /// Refreshes the access token using the refresh token
  ///
  /// Returns:
  /// - [AuthResponse] containing the new session
  ///
  /// Throws:
  /// - [AuthException] if refresh fails
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Listen to authentication state changes
  ///
  /// Returns a stream of [AuthState] events that emit when:
  /// - User logs in
  /// - User logs out
  /// - Session is refreshed
  /// - User data is updated
  /// - Initial session is loaded
  ///
  /// Example:
  /// ```dart
  /// authService.onAuthStateChanged().listen((data) {
  ///   final event = data.event;
  ///   final session = data.session;
  ///
  ///   switch (event) {
  ///     case AuthChangeEvent.signedIn:
  ///       print('User signed in');
  ///       break;
  ///     case AuthChangeEvent.signedOut:
  ///       print('User signed out');
  ///       break;
  ///     case AuthChangeEvent.tokenRefreshed:
  ///       print('Token refreshed');
  ///       break;
  ///     default:
  ///       break;
  ///   }
  /// });
  /// ```
  Stream<AuthState> onAuthStateChanged() {
    return _supabase.auth.onAuthStateChange;
  }

  /// Get user identities linked to the current user
  ///
  /// Returns:
  /// - [List<UserIdentity>]: List of identities linked to the user
  ///
  /// Throws:
  /// - [AuthException] if not authenticated or if operation fails
  Future<List<UserIdentity>> getUserIdentities() async {
    try {
      final identities = await _supabase.auth.getUserIdentities();
      return identities;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with OAuth provider (Google, GitHub, etc.)
  ///
  /// Parameters:
  /// - [provider]: The OAuth provider to use (OAuthProvider.google, etc.)
  /// - [redirectTo]: Optional redirect URL after authentication
  /// - [scopes]: Optional scopes to request from the provider
  ///
  /// Returns: void (handles navigation internally)
  ///
  /// Throws:
  /// - [AuthException] if OAuth sign-in fails
  Future<void> signInWithOAuth({
    required OAuthProvider provider,
    String? redirectTo,
    String? scopes,
  }) async {
    try {
      await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
        scopes: scopes,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with magic link (passwordless authentication)
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [redirectTo]: Optional redirect URL after clicking the magic link
  ///
  /// Returns: void
  ///
  /// Throws:
  /// - [AuthException] if operation fails
  Future<void> signInWithMagicLink({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectTo,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Verify an OTP (One-Time Password) for login
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [token]: The OTP token sent to the user's email
  /// - [type]: The type of OTP (signup, recovery, etc.)
  ///
  /// Returns:
  /// - [AuthResponse] containing the user and session
  ///
  /// Throws:
  /// - [AuthException] if verification fails
  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        type: type,
        token: token,
        email: email,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Send a password reset email
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [redirectTo]: Optional redirect URL for the reset link
  ///
  /// Returns: void
  ///
  /// Throws:
  /// - [AuthException] if operation fails
  Future<void> resetPassword({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
    } catch (e) {
      rethrow;
    }
  }

  /// Get the access token of the current session
  ///
  /// Returns:
  /// - [String?]: The access token if session exists, null otherwise
  String? getAccessToken() {
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Get the refresh token of the current session
  ///
  /// Returns:
  /// - [String?]: The refresh token if session exists, null otherwise
  String? getRefreshToken() {
    return _supabase.auth.currentSession?.refreshToken;
  }

  /// Get the Supabase client instance
  ///
  /// Returns:
  /// - [SupabaseClient]: The Supabase client for direct access if needed
  SupabaseClient getSupabaseClient() {
    return _supabase;
  }
}
