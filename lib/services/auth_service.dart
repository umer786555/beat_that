import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_that/services/preferences_service.dart';

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
  static const String emailUpgradeCallbackHost = 'email-upgrade-callback';
  static const String emailUpgradeCallbackUrl =
      '$authCallbackScheme://$emailUpgradeCallbackHost';
  static const String currentLegalVersion = '2026-09-11';
  static const String _acceptedTermsAtKey = 'accepted_terms_at';
  static const String _acceptedTermsVersionKey = 'accepted_terms_version';
  static const String _acceptedPrivacyAtKey = 'accepted_privacy_at';
  static const String _acceptedPrivacyVersionKey = 'accepted_privacy_version';
  static const String _pendingEmailUpgradeKey = 'pending_email_upgrade';
  static const String _pendingPasswordSetupLocalKey =
      'pending_email_upgrade_password_setup';
  static const List<String> _googleAuthScopes = ['email', 'profile'];
  static const String googleWebClientId =
      '310151412384-g8q3ocri52hp0n7g81gq0k3ecsuil609.apps.googleusercontent.com';
  static const String googleIosClientId =
      '310151412384-4l2comqgb132p4erqui0hbb48i88a3fo.apps.googleusercontent.com';

  final SupabaseClient _supabase;
  final PreferencesService _preferencesService;
  final GoogleSignIn _googleSignIn;
  final bool Function() _isAndroid;
  final bool Function() _isIOS;
  bool _googleSignInInitialized = false;
  User? _resolvedUser;

  User? get _activeUser => _supabase.auth.currentUser ?? _resolvedUser;

  AuthResponse _storeAuthResponse(AuthResponse response) {
    _resolvedUser = response.user ?? _supabase.auth.currentUser;
    return response;
  }

  List<String> _authProvidersForUser([User? user]) {
    final providers = user?.appMetadata['providers'];

    if (providers is List) {
      return providers.map((provider) => provider.toString()).toList();
    }

    if (providers is String && providers.isNotEmpty) {
      return [providers];
    }

    return const [];
  }

  bool _userUsesGoogleAuth([User? user]) {
    return _authProvidersForUser(
      user,
    ).any((provider) => provider.toLowerCase() == 'google');
  }

  // On Android, Credential Manager can report a canceled auth attempt when it
  // is actually holding stale app authorization for a Google account that was
  // deleted in Supabase. In that case we can clear Google's app state and retry.
  bool _isRecoverableGoogleReauthFailure(GoogleSignInException error) {
    if (!_isAndroid() || error.code != GoogleSignInExceptionCode.canceled) {
      return false;
    }

    final normalizedDescription = (error.description ?? '').toLowerCase();
    final normalizedDetails = error.details?.toString().toLowerCase() ?? '';

    return normalizedDescription.contains('account reauth failed') ||
        normalizedDetails.contains('account reauth failed');
  }

  bool _shouldRetryRecoverableGoogleReauthFailure() {
    if (!_isAndroid()) {
      return false;
    }

    final user = _activeUser;
    if (user == null || user.isAnonymous) {
      return false;
    }

    return _userUsesGoogleAuth(user);
  }

  // `signOut()` clears local credential state. `disconnect()` goes further and
  // revokes the app's Google authorization so the next auth starts clean.
  Future<void> _clearGoogleSession({bool revokeAccess = false}) async {
    if (!(_isAndroid() || _isIOS()) || googleWebClientId.isEmpty) {
      return;
    }

    await _initializeGoogleSignIn();

    try {
      if (revokeAccess) {
        await _googleSignIn.disconnect();
      } else {
        await _googleSignIn.signOut();
      }
    } catch (error) {
      if (!revokeAccess) {
        rethrow;
      }

      await _googleSignIn.signOut();
    }
  }

  // Authenticate with Google first, before touching Supabase. If Android
  // Credential Manager fails with the stale-reauth case above, clear the
  // Google state once and retry a single time.
  Future<GoogleSignInAccount> _authenticateGoogleUser({
    bool allowRetry = true,
  }) async {
    try {
      return await _googleSignIn.authenticate(scopeHint: _googleAuthScopes);
    } on GoogleSignInException catch (error) {
      if (!allowRetry ||
          !_isRecoverableGoogleReauthFailure(error) ||
          !_shouldRetryRecoverableGoogleReauthFailure()) {
        rethrow;
      }

      await _clearGoogleSession(revokeAccess: true);

      return _authenticateGoogleUser(allowRetry: false);
    }
  }

  Future<String> _authorizeGoogleAccessToken(
    GoogleSignInAccount googleUser,
  ) async {
    final existingAuthorization = await _googleSignIn.authorizationClient
        .authorizationForScopes(_googleAuthScopes);
    final authorization =
        existingAuthorization ??
        await _googleSignIn.authorizationClient.authorizeScopes(
          _googleAuthScopes,
        );

    return authorization.accessToken;
  }

  bool _shouldFallbackToSocialSignInError(Object error) {
    final normalizedDetails = error.toString().toLowerCase();

    if (error is AuthException) {
      final normalizedCode = (error.code ?? '').toLowerCase();

      if (normalizedCode == 'identity_already_exists' ||
          normalizedCode == 'email_exists' ||
          normalizedCode == 'user_already_exists') {
        return true;
      }
    }

    // Check if the error message contains indicators that we should fall back to signin
    // This includes cases where the identity is already linked or the email is already in use
    return normalizedDetails.contains('already exists for that email') ||
        normalizedDetails.contains('user already registered') ||
        normalizedDetails.contains('already linked to another user') ||
        normalizedDetails.contains('identity already exists') ||
        normalizedDetails.contains('identity_already_exists') ||
        normalizedDetails.contains('email_exists') ||
        normalizedDetails.contains('user_already_exists') ||
        normalizedDetails.contains('the user is not anonymous') ||
        normalizedDetails.contains('should be anonymous') ||
        normalizedDetails.contains('conflicting email');
  }

  bool isEmailUpgradeCallbackUri(Uri uri) {
    return uri.scheme == authCallbackScheme &&
        uri.host == emailUpgradeCallbackHost;
  }

  AuthService({
    SupabaseClient? supabase,
    required PreferencesService preferencesService,
    GoogleSignIn? googleSignIn,
    bool Function()? isAndroid,
    bool Function()? isIOS,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _preferencesService = preferencesService,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _isAndroid = isAndroid ?? (() => Platform.isAndroid),
       _isIOS = isIOS ?? (() => Platform.isIOS);

  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignInInitialized) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId: googleWebClientId.isEmpty ? null : googleWebClientId,
      clientId: _isIOS() && googleIosClientId.isNotEmpty
          ? googleIosClientId
          : null,
    );
    _googleSignInInitialized = true;
  }

  Map<String, dynamic> buildLegalAcceptanceMetadata({DateTime? acceptedAt}) {
    final acceptedAtIso = (acceptedAt ?? DateTime.now())
        .toUtc()
        .toIso8601String();

    return {
      _acceptedTermsAtKey: acceptedAtIso,
      _acceptedTermsVersionKey: currentLegalVersion,
      _acceptedPrivacyAtKey: acceptedAtIso,
      _acceptedPrivacyVersionKey: currentLegalVersion,
    };
  }

  bool hasAcceptedCurrentLegalVersion() {
    final metadata = _activeUser?.userMetadata;
    if (metadata == null) {
      return false;
    }

    return metadata[_acceptedTermsVersionKey]?.toString() ==
            currentLegalVersion &&
        metadata[_acceptedPrivacyVersionKey]?.toString() == currentLegalVersion;
  }

  Future<UserResponse> updateUserMetadata(Map<String, dynamic> updates) async {
    final currentMetadata = Map<String, dynamic>.from(
      _activeUser?.userMetadata ?? {},
    );

    currentMetadata.addAll(updates);

    return updateUser(UserAttributes(data: currentMetadata));
  }

  Future<UserResponse> recordLegalAcceptance({DateTime? acceptedAt}) async {
    return updateUserMetadata(
      buildLegalAcceptanceMetadata(acceptedAt: acceptedAt),
    );
  }

  bool isPendingEmailUpgrade() {
    final metadata = _activeUser?.userMetadata;
    if (metadata == null) {
      return false;
    }

    final rawValue = metadata[_pendingEmailUpgradeKey];
    return rawValue == true || rawValue?.toString().toLowerCase() == 'true';
  }

  bool hasPendingPasswordSetupLocal() {
    return _preferencesService.getBool(_pendingPasswordSetupLocalKey);
  }

  bool hasPendingEmailUpgradeFlow() {
    return isPendingEmailUpgrade() || hasPendingPasswordSetupLocal();
  }

  Future<void> markPendingEmailUpgradePasswordSetup() async {
    await _preferencesService.setBool(_pendingPasswordSetupLocalKey, true);
  }

  Future<void> clearPendingEmailUpgradePasswordSetup() async {
    await _preferencesService.remove(_pendingPasswordSetupLocalKey);
  }

  Future<UserResponse> _replaceUserMetadata(
    Map<String, dynamic> metadata, {
    String? emailRedirectTo,
    String? password,
  }) {
    return updateUser(
      UserAttributes(data: metadata, password: password),
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<UserResponse> clearPendingEmailUpgrade() async {
    final metadata = Map<String, dynamic>.from(_activeUser?.userMetadata ?? {})
      ..[_pendingEmailUpgradeKey] = false;

    final response = await _replaceUserMetadata(metadata);
    await clearPendingEmailUpgradePasswordSetup();
    return response;
  }

  /// Converts an anonymous user to an email-authenticated user.
  ///
  /// Deprecated: Use [upgradeAnonymousUserToEmail] instead, which has better
  /// documentation and clearer intent.
  ///
  /// This method sends a confirmation email to verify the provided email address.
  /// The user must click the confirmation link to complete the upgrade.
  Future<UserResponse> linkEmailToAnonymousUser({
    required String email,
    Map<String, dynamic>? userData,
    String? emailRedirectTo,
  }) async {
    return upgradeAnonymousUserToEmail(
      email: email,
      userData: userData,
      emailRedirectTo: emailRedirectTo,
    );
  }

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
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo ?? authCallbackUrl,
      data: userData,
    );
    return _storeAuthResponse(response);
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
      return _storeAuthResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    if (googleWebClientId.isEmpty) {
      throw const AuthException(
        'Missing Google web client ID in AuthService.',
        code: 'google_config_missing',
      );
    }

    if (!(_isAndroid() || _isIOS())) {
      throw const AuthException(
        'Native Google Sign-In is only configured for Android and iOS.',
        code: 'google_platform_unsupported',
      );
    }

    try {
      await _initializeGoogleSignIn();

      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthException(
          'Google Sign-In is not supported on this device.',
          code: 'google_auth_unsupported',
        );
      }

      final googleUser = await _authenticateGoogleUser();

      final authentication = googleUser.authentication;
      final accessToken = await _authorizeGoogleAccessToken(googleUser);
      final idToken = authentication.idToken;
      final shouldLinkAnonymousUser = isAnonymousUser();

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'No Google ID token was returned.',
          code: 'google_id_token_missing',
        );
      }

      if (shouldLinkAnonymousUser) {
        try {
          // Preferred path for guest users: preserve the anonymous user id and
          // attach Google to that same account.
          final response = await _supabase.auth.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
          return _storeAuthResponse(response);
        } catch (error) {
          if (!_shouldFallbackToSocialSignInError(error)) {
            rethrow;
          }

          // If Google is already linked to another existing Supabase user,
          // switch from "link" to a normal sign-in rather than hard-failing.
          final response = await _supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
          return _storeAuthResponse(response);
        }
      }

      // Non-anonymous users always take the direct sign-in path.
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return _storeAuthResponse(response);
    } on GoogleSignInException catch (error) {
      if (_isRecoverableGoogleReauthFailure(error)) {
        throw AuthException(
          error.description ?? 'Google account reauthorization failed.',
          code: 'google_reauth_failed',
        );
      }
      throw AuthException(
        error.description ?? 'Google sign-in failed.',
        code: 'google_${error.code.name}',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  Future<AuthResponse> signInWithApple() async {
    if (!_isIOS()) {
      throw const AuthException(
        'Native Apple Sign-In is only configured for iOS.',
        code: 'apple_platform_unsupported',
      );
    }

    final isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw const AuthException(
        'Apple Sign-In is not available on this device.',
        code: 'apple_not_available',
      );
    }

    final rawNonce = _supabase.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      final shouldLinkAnonymousUser = isAnonymousUser();

      // Apple follows the same account-shape decision as Google:
      // link onto the current anonymous user when we are in guest mode,
      // otherwise sign into the existing Apple-backed account directly.
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'No Apple ID token was returned.',
          code: 'apple_id_token_missing',
        );
      }

      final response = shouldLinkAnonymousUser
          ? await (() async {
              try {
                // Preferred guest-upgrade path: keep the anonymous Supabase user
                // and attach the Apple identity to that same account.
                debugPrint(
                  '[APPLE_SIGNIN] Attempting to link identity to anonymous user',
                );
                final result = await _supabase.auth.linkIdentityWithIdToken(
                  provider: OAuthProvider.apple,
                  idToken: idToken,
                  nonce: rawNonce,
                );
                debugPrint('[APPLE_SIGNIN] Successfully linked identity');
                return _storeAuthResponse(result);
              } catch (error) {
                debugPrint('[APPLE_SIGNIN] Link failed: $error');
                debugPrint('[APPLE_SIGNIN] Error type: ${error.runtimeType}');

                if (!_shouldFallbackToSocialSignInError(error)) {
                  debugPrint(
                    '[APPLE_SIGNIN] Error does not match fallback criteria, rethrowing',
                  );
                  rethrow;
                }

                // If Apple is already linked to another existing Supabase user,
                // switch from link mode to a normal sign-in instead of failing.
                debugPrint('[APPLE_SIGNIN] Falling back to signInWithIdToken');
                final result = await _supabase.auth.signInWithIdToken(
                  provider: OAuthProvider.apple,
                  idToken: idToken,
                  nonce: rawNonce,
                );
                return _storeAuthResponse(result);
              }
            })()
          : _storeAuthResponse(
              // Non-anonymous users always take the direct sign-in path.
              await _supabase.auth.signInWithIdToken(
                provider: OAuthProvider.apple,
                idToken: idToken,
                nonce: rawNonce,
              ),
            );

      // Apple only provides name fields on the first successful authorization,
      // so persist them immediately when they are available.
      if (credential.givenName != null || credential.familyName != null) {
        final nameParts = <String>[
          if (credential.givenName != null) credential.givenName!,
          if (credential.familyName != null) credential.familyName!,
        ];

        try {
          await updateUserMetadata({
            'full_name': nameParts.join(' '),
            'given_name': credential.givenName,
            'family_name': credential.familyName,
          });
        } catch (error, stackTrace) {
          debugPrint('Apple sign-in profile update failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      return response;
    } on SignInWithAppleAuthorizationException catch (error) {
      throw AuthException(error.message, code: 'apple_${error.code.name}');
    }
  }

  /// Sign out the current user
  ///
  /// Clears the Supabase session and the local Google credential state.
  ///
  /// When [revokeGoogleAccess] is true, this also revokes the app's Google
  /// authorization so future sign-in attempts do not reuse stale account state
  /// after a destructive action such as account deletion.
  ///
  /// Returns: void
  ///
  /// Throws:
  /// - [AuthException] if logout fails
  Future<void> logout({bool revokeGoogleAccess = false}) async {
    final userBeforeLogout = _activeUser;
    final shouldClearGoogleSession =
        revokeGoogleAccess ||
        _googleSignInInitialized ||
        _userUsesGoogleAuth(userBeforeLogout);
    Object? pendingError;
    StackTrace? pendingStackTrace;

    try {
      await _supabase.auth.signOut();
      clearResolvedUser();
      await clearPendingEmailUpgradePasswordSetup();
    } catch (error, stackTrace) {
      pendingError = error;
      pendingStackTrace = stackTrace;
    }

    if (shouldClearGoogleSession) {
      try {
        await _clearGoogleSession(revokeAccess: revokeGoogleAccess);
      } catch (error, stackTrace) {
        if (pendingError == null && !revokeGoogleAccess) {
          pendingError = error;
          pendingStackTrace = stackTrace;
        }
      }
    }

    if (pendingError != null && pendingStackTrace != null) {
      Error.throwWithStackTrace(pendingError, pendingStackTrace);
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

  /// Check whether the current signed-in user is anonymous.
  bool isAnonymousUser() {
    final user = _activeUser;
    return user?.isAnonymous ?? false;
  }

  /// Check whether the current signed-in user has a permanent account.
  bool hasFullAccountAccess() {
    return isLoggedIn() &&
        !isAnonymousUser() &&
        !requiresEmailUpgradePasswordSetup();
  }

  bool hasConfirmedEmailIdentity() {
    final user = _activeUser;
    return (user?.email?.isNotEmpty ?? false) && user?.emailConfirmedAt != null;
  }

  bool hasPendingEmailConfirmation() {
    final user = _activeUser;
    final hasQueuedEmailChange = user?.newEmail?.isNotEmpty ?? false;

    if (hasQueuedEmailChange) {
      return true;
    }

    return user?.emailChangeSentAt != null && !hasConfirmedEmailIdentity();
  }

  bool requiresEmailUpgradePasswordSetup() {
    return hasPendingEmailUpgradeFlow() &&
        !hasPendingEmailConfirmation() &&
        hasConfirmedEmailIdentity();
  }

  Future<void> completePendingEmailUpgrade({required String password}) async {
    await updateUser(UserAttributes(password: password));
    await clearPendingEmailUpgrade();
  }

  Future<void> verifyEmailUpgradeCallback(Uri uri) async {
    final tokenHash = uri.queryParameters['token_hash'];
    final type = uri.queryParameters['type'];

    final fragmentParameters =
        uri.fragment.isEmpty || !uri.fragment.contains('=')
        ? const <String, String>{}
        : Uri.splitQueryString(uri.fragment);
    final errorDescription = fragmentParameters['error_description'];
    final errorCode = fragmentParameters['error_code'];

    if (errorDescription != null && errorDescription.isNotEmpty) {
      throw AuthException(
        Uri.decodeComponent(errorDescription),
        code: errorCode,
      );
    }

    final hasSessionCallback =
        fragmentParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('code');

    if (tokenHash != null && tokenHash.isNotEmpty) {
      if (type != 'email_change') {
        throw AuthException(
          'Unexpected email upgrade callback type: $type',
          code: 'email_upgrade_type_invalid',
        );
      }

      await _supabase.auth.verifyOTP(
        type: OtpType.emailChange,
        tokenHash: tokenHash,
      );
    } else if (!hasSessionCallback) {
      throw const AuthException(
        'Missing callback session or token hash in email upgrade callback.',
        code: 'email_upgrade_token_missing',
      );
    }

    await refreshCurrentUser();
  }

  Future<User?> refreshCurrentUser() async {
    if (!isLoggedIn()) {
      _resolvedUser = _supabase.auth.currentUser;
      return _resolvedUser;
    }

    final response = await _supabase.auth.getUser();
    _resolvedUser = response.user ?? _supabase.auth.currentUser;
    return _resolvedUser;
  }

  void clearResolvedUser() {
    _resolvedUser = null;
  }

  /// Converts an anonymous user to an email-authenticated user.
  ///
  /// This method upgrades an anonymous user account by sending a confirmation
  /// email to verify their email address. The user must click the confirmation
  /// link in the email to complete the upgrade.
  ///
  /// **Important:** Supabase treats adding the first email to an anonymous user
  /// as an "email change" operation. The confirmation email sent will contain
  /// `type=email_change` in the callback URL. This is expected behavior.
  ///
  /// Parameters:
  /// - [email]: The email address to link to the anonymous account
  /// - [userData]: Optional metadata to update during the upgrade
  /// - [password]: Optional password to set on the account
  /// - [emailRedirectTo]: Optional redirect URL after email confirmation
  ///
  /// Returns:
  /// - [UserResponse] containing the updated user
  ///
  /// Throws:
  /// - [AuthException] if the user is not anonymous or the upgrade fails
  ///
  /// Flow:
  /// 1. User provides email and optional password
  /// 2. App calls this method with email + optional password
  /// 3. Supabase sends email_change confirmation email
  /// 4. User clicks link in email → deep link with token_hash and type=email_change
  /// 5. App handles deep link in verifyEmailUpgradeCallback()
  /// 6. Supabase confirms the email → email verified
  /// 7. User can now sign in with email+password
  Future<UserResponse> upgradeAnonymousUserToEmail({
    required String email,
    Map<String, dynamic>? userData,
    String? password,
    String? emailRedirectTo,
  }) async {
    if (!isAnonymousUser()) {
      throw const AuthException(
        'User is not anonymous. Cannot upgrade non-anonymous user.',
        code: 'email_upgrade_not_anonymous',
      );
    }

    final currentMetadata = Map<String, dynamic>.from(
      _activeUser?.userMetadata ?? {},
    );

    if (userData != null) {
      currentMetadata.addAll(userData);
    }

    currentMetadata[_pendingEmailUpgradeKey] = true;

    try {
      await markPendingEmailUpgradePasswordSetup();

      final response = await updateUser(
        UserAttributes(email: email, data: currentMetadata, password: password),
        emailRedirectTo: emailRedirectTo,
      );

      return response;
    } catch (e) {
      await clearPendingEmailUpgradePasswordSetup();
      rethrow;
    }
  }

  /// Restore a valid session if one exists, otherwise create an anonymous one.
  Future<void> ensureAnonymousSession({Map<String, dynamic>? userData}) async {
    final currentSession = _supabase.auth.currentSession;

    if (currentSession != null && !currentSession.isExpired) {
      return;
    }

    if (currentSession != null) {
      try {
        final refreshedSession = await _supabase.auth.refreshSession();
        if (refreshedSession.session != null) {
          return;
        }
      } on AuthException catch (error, stackTrace) {
        debugPrint('Failed to refresh auth session: ${error.message}');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final response = await _supabase.auth.signInAnonymously(data: userData);
    _resolvedUser = response.user ?? _supabase.auth.currentUser;
  }

  /// Get the currently logged-in user
  ///
  /// Returns:
  /// - [User?]: The current user if logged in, null otherwise
  User? getCurrentUser() {
    return _activeUser;
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
    return _activeUser?.id;
  }

  /// Get the current user's email
  ///
  /// Returns:
  /// - [String?]: The user email if logged in, null otherwise
  String? getCurrentUserEmail() {
    return _activeUser?.email;
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
  Future<UserResponse> updateUser(
    UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        attributes,
        emailRedirectTo: emailRedirectTo,
      );
      _resolvedUser = response.user ?? _supabase.auth.currentUser;

      if (isLoggedIn()) {
        try {
          await refreshCurrentUser();
        } on AuthException catch (error, stackTrace) {
          debugPrint('Auth user refresh after update failed: ${error.message}');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

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
      return _storeAuthResponse(response);
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
      return _storeAuthResponse(response);
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
