import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;

import '../domain/auth_gateway.dart';
import '../services/firebase_facebook_auth_service.dart';
import 'authenticated_api_client.dart';
import 'session_token_store.dart';

class FacebookAuthGateway implements AuthGateway, FacebookAccountLinker {
  FacebookAuthGateway({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? apiBaseUrl,
    FirebaseFacebookAuthenticator? firebaseFacebookAuthenticator,
    Future<LoginResult> Function(String nonce)? facebookLogin,
  }) : _client = client ?? http.Client(),
       _storage = SessionTokenStore(secureStorage: storage),
       _authenticatedClient = AuthenticatedApiClient(
         client: client,
         storage: storage,
         apiBaseUrl: apiBaseUrl,
       ),
       _firebaseFacebookAuthenticator =
           firebaseFacebookAuthenticator ??
           DefaultFirebaseFacebookAuthenticator(),
       _facebookLogin =
           facebookLogin ??
           ((nonce) => FacebookAuth.instance.login(
             permissions: const ['email', 'public_profile'],
             nonce: nonce,
           )),
       _apiBaseUrl =
           apiBaseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'https://hexora.dev',
           );

  final http.Client _client;
  final SessionTokenStore _storage;
  final AuthenticatedApiClient _authenticatedClient;
  final FirebaseFacebookAuthenticator _firebaseFacebookAuthenticator;
  final Future<LoginResult> Function(String nonce) _facebookLogin;
  final String _apiBaseUrl;
  Future<void>? _googleInitialization;

  static const _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '414702659593-94b8of4j0mgj16pr0r13a6a1dpm9mvpu.apps.googleusercontent.com',
  );

  @override
  Future<bool> hasSession() async =>
      (await _storage.read(
        AuthenticatedApiClient.refreshTokenKey,
      ))?.isNotEmpty ==
      true;

  @override
  Future<AuthSession> signInWithFacebook() async {
    final login = await _authenticateWithFacebook();
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/api/auth/facebook'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'accessToken': login.token.tokenString,
        'tokenType': login.token.type.name,
        'nonce': login.nonce,
        'firebaseIdToken': login.firebase.idToken,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(
        body['message'] as String? ?? 'Unable to sign in to Wicchu.',
        code: body['code'] as String?,
      );
    }

    return _saveSession(body);
  }

  @override
  Future<bool> isFacebookLinked() async {
    final result = await _authenticatedClient.get('/api/auth/connections');
    return result['facebook'] == true;
  }

  @override
  Future<void> linkFacebookAccount() async {
    final login = await _authenticateWithFacebook();
    await _authenticatedClient.post(
      '/api/auth/facebook/link',
      body: {
        'accessToken': login.token.tokenString,
        'tokenType': login.token.type.name,
        'nonce': login.nonce,
        'firebaseIdToken': login.firebase.idToken,
      },
    );
  }

  Future<_FacebookCredentialBundle> _authenticateWithFacebook() async {
    if (kIsWeb && !FacebookAuth.instance.isWebSdkInitialized) {
      const appId = String.fromEnvironment('FACEBOOK_APP_ID');
      const graphVersion = String.fromEnvironment('FACEBOOK_GRAPH_VERSION');
      if (appId.isEmpty || graphVersion.isEmpty) {
        throw const AuthException('Facebook web login is not configured.');
      }
      await FacebookAuth.instance.webAndDesktopInitialize(
        appId: appId,
        cookie: true,
        xfbml: true,
        version: graphVersion,
      );
    }
    final nonce = _createNonce();
    late final LoginResult result;
    try {
      result = await _facebookLogin(nonce);
    } catch (error) {
      developer.log(
        'Facebook SDK exception=${error.runtimeType} accessTokenReturned=false',
        name: 'wicchu.facebook_auth',
      );
      throw const AuthException(
        'Facebook Login failed before returning a result.',
        code: 'FACEBOOK_SDK_EXCEPTION',
      );
    }
    developer.log(
      'Facebook Login result status=${result.status.name} '
      'message=${result.message ?? 'none'} '
      'accessTokenReturned=${result.accessToken != null}',
      name: 'wicchu.facebook_auth',
    );
    if (result.status == LoginStatus.cancelled) {
      throw const AuthException('Facebook sign-in was cancelled.');
    }
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw AuthException(result.message ?? 'Facebook sign-in failed.');
    }

    final facebookToken = result.accessToken!;
    late final FirebaseFacebookAuthResult firebaseResult;
    try {
      firebaseResult = await _firebaseFacebookAuthenticator.authenticate(
        facebookToken.tokenString,
      );
    } on FirebaseFacebookAuthFailure catch (error) {
      throw AuthException(error.message, code: error.code);
    }
    return _FacebookCredentialBundle(
      token: facebookToken,
      firebase: firebaseResult,
      nonce: nonce,
    );
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    if (_googleWebClientId.isEmpty) {
      throw const AuthException('Google sign-in is not configured.');
    }
    final signIn = GoogleSignIn.instance;
    _googleInitialization ??= signIn.initialize(
      clientId: kIsWeb ? _googleWebClientId : null,
      serverClientId: _googleWebClientId,
    );
    await _googleInitialization;
    if (!signIn.supportsAuthenticate()) {
      throw const AuthException(
        'Google sign-in is not available on this platform.',
      );
    }
    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google did not return an identity token.');
    }
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/api/auth/google'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(
        body['message'] as String? ?? 'Unable to sign in with Google.',
      );
    }
    return _saveSession(body);
  }

  @override
  Future<AuthSession> signInWithApple() async {
    final applePayload = await _appleCredentialPayload();
    final body = await _postAuth(
      '/api/auth/apple',
      applePayload,
      successCodes: const {200, 201},
    );
    return _saveSession(body);
  }

  Future<Map<String, dynamic>> _appleCredentialPayload() async {
    final challenge = await _postAuth(
      '/api/auth/apple/challenge',
      const {},
      successCodes: const {201},
    );
    final rawNonce = challenge['nonce'] as String?;
    final challengeId = challenge['challengeId'] as String?;
    if (rawNonce == null || challengeId == null) {
      throw const AuthException(
        'The server returned an invalid Apple login challenge.',
      );
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    if (credential.identityToken == null ||
        credential.authorizationCode.isEmpty) {
      throw const AuthException(
        'Apple did not return valid sign-in credentials.',
      );
    }
    return {
      'challengeId': challengeId,
      'identityToken': credential.identityToken,
      'authorizationCode': credential.authorizationCode,
      'givenName': credential.givenName,
      'familyName': credential.familyName,
    };
  }

  @override
  Future<AuthSession> signInWithEmail(String email, String password) async {
    final body = await _postAuth('/api/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    return _saveSession(body);
  }

  @override
  Future<void> registerWithEmail({
    required String name,
    required String userName,
    required String email,
    required String password,
    required String locale,
  }) async {
    await _postAuth(
      '/api/auth/register',
      {
        'name': name.trim(),
        'userName': userName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'locale': locale == 'es' ? 'es' : 'en',
        'app': 'wicchu',
      },
      successCodes: const {201},
    );
  }

  @override
  Future<void> resendVerificationEmail(
    String email, {
    required String locale,
  }) async {
    await _postAuth('/api/auth/resend-verification', {
      'email': email.trim().toLowerCase(),
      'locale': locale == 'es' ? 'es' : 'en',
      'app': 'wicchu',
    });
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _postAuth('/api/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    });
  }

  @override
  Future<Map<String, dynamic>> getDeletionPreview() async =>
      _authenticatedRequest('GET', '/api/community/v1/me/deletion-preview');

  @override
  Future<void> deleteAccount({String? password}) async {
    final profile = await _authenticatedRequest('GET', '/api/auth/profile');
    final provider = profile['registrationProvider'] as String? ?? 'password';
    final payload = <String, dynamic>{'provider': provider};
    if (provider == 'password') {
      if (password == null || password.isEmpty) {
        throw const AuthException(
          'Enter your password to delete your account.',
        );
      }
      payload['password'] = password;
    } else if (provider == 'google') {
      final signIn = GoogleSignIn.instance;
      _googleInitialization ??= signIn.initialize(
        clientId: kIsWeb ? _googleWebClientId : null,
        serverClientId: _googleWebClientId,
      );
      await _googleInitialization;
      final account = await signIn.authenticate();
      payload['idToken'] = account.authentication.idToken;
    } else if (provider == 'facebook') {
      final nonce = _createNonce();
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
        nonce: nonce,
      );
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw const AuthException('Facebook verification was cancelled.');
      }
      payload
        ..['accessToken'] = result.accessToken!.tokenString
        ..['tokenType'] = result.accessToken!.type.name
        ..['nonce'] = nonce;
    } else if (provider == 'apple') {
      payload.addAll(await _appleCredentialPayload());
    }
    final proof = await _authenticatedRequest(
      'POST',
      '/api/auth/reauthenticate',
      body: payload,
    );
    final token = proof['reauthenticationToken'] as String?;
    if (token == null) {
      throw const AuthException('Account verification failed.');
    }
    await _authenticatedRequest(
      'POST',
      '/api/community/v1/me/deletion',
      body: {'confirmation': 'DELETE', 'reauthenticationToken': token},
      extraHeaders: {'Idempotency-Key': _createNonce()},
    );
    await _clearLocalSession();
  }

  Future<Map<String, dynamic>> _authenticatedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
  }) async {
    final token = await _storage.read(AuthenticatedApiClient.accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const AuthException('Please sign in again.');
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
      ...extraHeaders,
    };
    final uri = Uri.parse('$_apiBaseUrl$path');
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final result = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        result['message'] as String? ?? 'Unable to complete the request.',
        code: result['code'] as String?,
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> _postAuth(
    String path,
    Map<String, dynamic> payload, {
    Set<int> successCodes = const {200},
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final decoded = jsonDecode(response.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    if (!successCodes.contains(response.statusCode)) {
      throw AuthException(
        body['message'] as String? ??
            body['error'] as String? ??
            'Unable to complete the request.',
        code: body['code'] as String?,
      );
    }
    return body;
  }

  Future<AuthSession> _saveSession(Map<String, dynamic> body) async {
    final session = AuthSession(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      userId: body['userId'] as String,
      userName: body['userName'] as String,
      isNewUser: body['isNewUser'] as bool? ?? false,
    );
    await Future.wait([
      _storage.write(
        AuthenticatedApiClient.accessTokenKey,
        session.accessToken,
      ),
      _storage.write(
        AuthenticatedApiClient.refreshTokenKey,
        session.refreshToken,
      ),
    ]);
    return session;
  }

  @override
  Future<void> signOut() async {
    final accessToken = await _storage.read(
      AuthenticatedApiClient.accessTokenKey,
    );
    if (accessToken?.isNotEmpty == true) {
      try {
        await _client.post(
          Uri.parse('$_apiBaseUrl/api/auth/logout'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
      } catch (_) {
        // Local sign-out must still succeed when the network is unavailable.
      }
    }
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    await Future.wait([
      FacebookAuth.instance.logOut(),
      GoogleSignIn.instance.signOut(),
      _storage.delete(AuthenticatedApiClient.accessTokenKey),
      _storage.delete(AuthenticatedApiClient.refreshTokenKey),
    ]);
  }

  String _createNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(sha256.convert(bytes).bytes).replaceAll('=', '');
  }
}

class _FacebookCredentialBundle {
  const _FacebookCredentialBundle({
    required this.token,
    required this.firebase,
    required this.nonce,
  });

  final AccessToken token;
  final FirebaseFacebookAuthResult firebase;
  final String nonce;
}
