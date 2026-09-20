import 'package:beat_that/services/auth_service.dart';
import 'package:beat_that/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockPreferencesService extends Mock implements PreferencesService {}

class FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  FakeGoogleSignInPlatform({
    this.authenticateResults = const [],
    this.supportsAuthenticateResult = true,
    this.silentAuthorizationToken,
    this.interactiveAuthorizationToken,
  });

  final List<Object> authenticateResults;
  final bool supportsAuthenticateResult;
  final ClientAuthorizationTokenData? silentAuthorizationToken;
  final ClientAuthorizationTokenData? interactiveAuthorizationToken;
  int initCalls = 0;
  int authenticateCalls = 0;
  int disconnectCalls = 0;
  int signOutCalls = 0;
  List<String> lastAuthenticateScopeHint = const [];
  final List<AuthorizationRequestDetails> authorizationRequests = [];

  @override
  Future<void> init(InitParameters params) async {
    initCalls += 1;
  }

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    return null;
  }

  @override
  bool supportsAuthenticate() => supportsAuthenticateResult;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authenticateCalls += 1;
    lastAuthenticateScopeHint = List<String>.from(params.scopeHint);
    final nextResult = authenticateResults[authenticateCalls - 1];

    if (nextResult is Exception) {
      throw nextResult;
    }

    return nextResult as AuthenticationResults;
  }

  @override
  bool authorizationRequiresUserInteraction() => true;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    authorizationRequests.add(params.request);
    return params.request.promptIfUnauthorized
        ? interactiveAuthorizationToken
        : silentAuthorizationToken;
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async {
    return null;
  }

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCalls += 1;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {
    disconnectCalls += 1;
  }
}

User _buildUser({
  required String id,
  required bool isAnonymous,
  String? email,
  Map<String, dynamic>? userMetadata,
}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: userMetadata,
    aud: 'authenticated',
    email: email,
    createdAt: '2026-09-12T00:00:00.000Z',
    emailConfirmedAt: email == null ? null : '2026-09-12T00:00:00.000Z',
    isAnonymous: isAnonymous,
  );
}

Session _buildSession(User user) {
  return Session(
    accessToken: 'not-a-real-jwt',
    tokenType: 'bearer',
    user: user,
  );
}

UserResponse _userResponse(User user) {
  return UserResponse.fromJson(user.toJson());
}

AuthResponse _authResponse(User user) {
  return AuthResponse(user: user, session: _buildSession(user));
}

AuthenticationResults _googleAuthenticationResults({
  required String email,
  required String id,
  required String idToken,
}) {
  return AuthenticationResults(
    user: GoogleSignInUserData(email: email, id: id),
    authenticationTokens: AuthenticationTokenData(idToken: idToken),
  );
}

ClientAuthorizationTokenData _googleAccessToken(String accessToken) {
  return ClientAuthorizationTokenData(accessToken: accessToken);
}

GoogleSignInException _googleReauthFailure() {
  return const GoogleSignInException(
    code: GoogleSignInExceptionCode.canceled,
    description: '[16] Account reauth failed.',
  );
}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockPreferencesService mockPreferencesService;
  late AuthService authService;
  late GoogleSignInPlatform originalGoogleSignInPlatform;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
  });

  setUp(() {
    originalGoogleSignInPlatform = GoogleSignInPlatform.instance;
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockPreferencesService = MockPreferencesService();

    when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(() => mockPreferencesService.getBool(any())).thenReturn(false);

    authService = AuthService(
      supabase: mockSupabaseClient,
      preferencesService: mockPreferencesService,
    );
  });

  tearDown(() {
    GoogleSignInPlatform.instance = originalGoogleSignInPlatform;
  });

  group('AuthService', () {
    test(
      'prefers the live Supabase user over a cached resolved user',
      () async {
        final anonymousUser = _buildUser(
          id: 'anon-user',
          isAnonymous: true,
          userMetadata: const {'guest_only': true},
        );
        final fullUser = _buildUser(
          id: 'full-user',
          isAnonymous: false,
          email: 'player@example.com',
          userMetadata: const {'account_type': 'full'},
        );

        when(
          () => mockGoTrueClient.currentSession,
        ).thenReturn(_buildSession(anonymousUser));
        when(() => mockGoTrueClient.currentUser).thenReturn(anonymousUser);
        when(
          () => mockGoTrueClient.getUser(),
        ).thenAnswer((_) async => _userResponse(anonymousUser));

        await authService.refreshCurrentUser();

        when(() => mockGoTrueClient.currentUser).thenReturn(fullUser);

        expect(authService.getCurrentUserId(), fullUser.id);
        expect(authService.isAnonymousUser(), isFalse);
        expect(authService.hasFullAccountAccess(), isTrue);
      },
    );

    test(
      'recordLegalAcceptance merges metadata from the live signed-in user',
      () async {
        final anonymousUser = _buildUser(
          id: 'anon-user',
          isAnonymous: true,
          userMetadata: const {'guest_only': true},
        );
        final fullUser = _buildUser(
          id: 'full-user',
          isAnonymous: false,
          email: 'player@example.com',
          userMetadata: const {'account_type': 'full'},
        );
        final acceptedAt = DateTime.utc(2026, 9, 12, 8, 30);

        when(
          () => mockGoTrueClient.currentSession,
        ).thenReturn(_buildSession(anonymousUser));
        when(() => mockGoTrueClient.currentUser).thenReturn(anonymousUser);
        when(
          () => mockGoTrueClient.getUser(),
        ).thenAnswer((_) async => _userResponse(anonymousUser));

        await authService.refreshCurrentUser();

        when(() => mockGoTrueClient.currentUser).thenReturn(fullUser);
        when(
          () => mockGoTrueClient.getUser(),
        ).thenAnswer((_) async => _userResponse(fullUser));

        late UserAttributes capturedAttributes;
        when(
          () =>
              mockGoTrueClient.updateUser(captureAny(), emailRedirectTo: null),
        ).thenAnswer((invocation) async {
          capturedAttributes =
              invocation.positionalArguments.first as UserAttributes;
          return _userResponse(fullUser);
        });

        await authService.recordLegalAcceptance(acceptedAt: acceptedAt);

        final data = capturedAttributes.data as Map<String, dynamic>;

        expect(data['account_type'], 'full');
        expect(data.containsKey('guest_only'), isFalse);
        expect(data['accepted_terms_at'], acceptedAt.toIso8601String());
        expect(data['accepted_terms_version'], AuthService.currentLegalVersion);
        expect(
          data['accepted_privacy_version'],
          AuthService.currentLegalVersion,
        );
      },
    );

    test(
      'does not preemptively clear Google app auth for anonymous Android upgrades',
      () async {
        final googlePlatform = FakeGoogleSignInPlatform(
          authenticateResults: [
            _googleAuthenticationResults(
              email: 'player@example.com',
              id: 'google-user-id',
              idToken: 'google-id-token',
            ),
          ],
          silentAuthorizationToken: _googleAccessToken('google-access-token'),
        );
        final anonymousUser = _buildUser(id: 'anon-user', isAnonymous: true);
        final signedInUser = _buildUser(
          id: 'supabase-user-id',
          isAnonymous: false,
          email: 'player@example.com',
        );

        GoogleSignInPlatform.instance = googlePlatform;
        when(
          () => mockGoTrueClient.currentSession,
        ).thenReturn(_buildSession(anonymousUser));
        when(() => mockGoTrueClient.currentUser).thenReturn(anonymousUser);
        when(
          () => mockGoTrueClient.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'google-id-token',
            accessToken: 'google-access-token',
          ),
        ).thenAnswer((_) async => _authResponse(signedInUser));

        authService = AuthService(
          supabase: mockSupabaseClient,
          preferencesService: mockPreferencesService,
          isAndroid: () => true,
          isIOS: () => false,
        );

        final response = await authService.signInWithGoogle();

        expect(response.user?.id, signedInUser.id);
        expect(googlePlatform.initCalls, 1);
        expect(googlePlatform.disconnectCalls, 0);
        expect(googlePlatform.authenticateCalls, 1);
        expect(googlePlatform.lastAuthenticateScopeHint, ['email', 'profile']);
        expect(googlePlatform.authorizationRequests, hasLength(1));
        expect(
          googlePlatform.authorizationRequests.single.promptIfUnauthorized,
          isFalse,
        );
      },
    );

    test(
      'skips preauth cleanup when already signed into a Google-backed account',
      () async {
        final googlePlatform = FakeGoogleSignInPlatform(
          authenticateResults: [
            _googleAuthenticationResults(
              email: 'player@example.com',
              id: 'google-user-id',
              idToken: 'google-id-token',
            ),
          ],
          silentAuthorizationToken: _googleAccessToken('google-access-token'),
        );
        final signedInUser = User(
          id: 'supabase-user-id',
          appMetadata: const {
            'providers': ['google'],
          },
          userMetadata: const {},
          aud: 'authenticated',
          email: 'player@example.com',
          createdAt: '2026-09-12T00:00:00.000Z',
          emailConfirmedAt: '2026-09-12T00:00:00.000Z',
          isAnonymous: false,
        );

        GoogleSignInPlatform.instance = googlePlatform;
        when(
          () => mockGoTrueClient.currentSession,
        ).thenReturn(_buildSession(signedInUser));
        when(() => mockGoTrueClient.currentUser).thenReturn(signedInUser);
        when(
          () => mockGoTrueClient.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'google-id-token',
            accessToken: 'google-access-token',
          ),
        ).thenAnswer((_) async => _authResponse(signedInUser));

        authService = AuthService(
          supabase: mockSupabaseClient,
          preferencesService: mockPreferencesService,
          isAndroid: () => true,
          isIOS: () => false,
        );

        await authService.signInWithGoogle();

        expect(googlePlatform.disconnectCalls, 0);
        expect(googlePlatform.authenticateCalls, 1);
        expect(googlePlatform.lastAuthenticateScopeHint, ['email', 'profile']);
      },
    );

    test(
      'retries recoverable Google reauth failures only for Google-backed sessions',
      () async {
        final googlePlatform = FakeGoogleSignInPlatform(
          authenticateResults: [
            _googleReauthFailure(),
            _googleAuthenticationResults(
              email: 'player@example.com',
              id: 'google-user-id',
              idToken: 'google-id-token',
            ),
          ],
          silentAuthorizationToken: _googleAccessToken('google-access-token'),
        );
        final signedInUser = User(
          id: 'supabase-user-id',
          appMetadata: const {
            'providers': ['google'],
          },
          userMetadata: const {},
          aud: 'authenticated',
          email: 'player@example.com',
          createdAt: '2026-09-12T00:00:00.000Z',
          emailConfirmedAt: '2026-09-12T00:00:00.000Z',
          isAnonymous: false,
        );

        GoogleSignInPlatform.instance = googlePlatform;
        when(
          () => mockGoTrueClient.currentSession,
        ).thenReturn(_buildSession(signedInUser));
        when(() => mockGoTrueClient.currentUser).thenReturn(signedInUser);
        when(
          () => mockGoTrueClient.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'google-id-token',
            accessToken: 'google-access-token',
          ),
        ).thenAnswer((_) async => _authResponse(signedInUser));

        authService = AuthService(
          supabase: mockSupabaseClient,
          preferencesService: mockPreferencesService,
          isAndroid: () => true,
          isIOS: () => false,
        );

        await authService.signInWithGoogle();

        expect(googlePlatform.disconnectCalls, 1);
        expect(googlePlatform.authenticateCalls, 2);
      },
    );

    test(
      'does not retry recoverable Google reauth failures for anonymous sessions',
      () async {
        final googlePlatform = FakeGoogleSignInPlatform(
          authenticateResults: [_googleReauthFailure()],
        );
        final anonymousUser = _buildUser(id: 'anon-user', isAnonymous: true);

        GoogleSignInPlatform.instance = googlePlatform;
        when(
          () => mockGoTrueClient.currentSession,
        ).thenReturn(_buildSession(anonymousUser));
        when(() => mockGoTrueClient.currentUser).thenReturn(anonymousUser);

        authService = AuthService(
          supabase: mockSupabaseClient,
          preferencesService: mockPreferencesService,
          isAndroid: () => true,
          isIOS: () => false,
        );

        await expectLater(
          authService.signInWithGoogle(),
          throwsA(isA<AuthException>()),
        );

        expect(googlePlatform.disconnectCalls, 0);
        expect(googlePlatform.authenticateCalls, 1);
      },
    );

    test(
      'requests interactive Google authorization when silent access token is unavailable',
      () async {
        final googlePlatform = FakeGoogleSignInPlatform(
          authenticateResults: [
            _googleAuthenticationResults(
              email: 'player@example.com',
              id: 'google-user-id',
              idToken: 'google-id-token',
            ),
          ],
          interactiveAuthorizationToken: _googleAccessToken(
            'interactive-google-access-token',
          ),
        );
        final signedInUser = _buildUser(
          id: 'supabase-user-id',
          isAnonymous: false,
          email: 'player@example.com',
        );

        GoogleSignInPlatform.instance = googlePlatform;
        when(() => mockGoTrueClient.currentSession).thenReturn(null);
        when(() => mockGoTrueClient.currentUser).thenReturn(null);
        when(
          () => mockGoTrueClient.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'google-id-token',
            accessToken: 'interactive-google-access-token',
          ),
        ).thenAnswer((_) async => _authResponse(signedInUser));

        authService = AuthService(
          supabase: mockSupabaseClient,
          preferencesService: mockPreferencesService,
          isAndroid: () => true,
          isIOS: () => false,
        );

        await authService.signInWithGoogle();

        expect(googlePlatform.authorizationRequests, hasLength(2));
        expect(
          googlePlatform.authorizationRequests.first.promptIfUnauthorized,
          isFalse,
        );
        expect(
          googlePlatform.authorizationRequests.last.promptIfUnauthorized,
          isTrue,
        );
      },
    );
  });
}
