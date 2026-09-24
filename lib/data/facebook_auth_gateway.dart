import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../domain/auth_gateway.dart';
import 'authenticated_api_client.dart';

class FacebookAuthGateway implements AuthGateway {
  FacebookAuthGateway({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _apiBaseUrl =
           apiBaseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'https://hexora.dev',
           );

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _apiBaseUrl;
  Future<void>? _googleInitialization;

  static const _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '109878335777-b5ifpb5bl635974b2f8p0hhovtuq18dc.apps.googleusercontent.com',
  );

  @override
  Future<bool> hasSession() async =>
      (await _storage.read(
        key: AuthenticatedApiClient.refreshTokenKey,
      ))?.isNotEmpty ==
      true;

  @override
  Future<AuthSession> signInWithFacebook() async {
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
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
      nonce: nonce,
    );
    if (result.status == LoginStatus.cancelled) {
      throw const AuthException('Facebook sign-in was cancelled.');
    }
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw AuthException(result.message ?? 'Facebook sign-in failed.');
    }

    final facebookToken = result.accessToken!;
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/api/auth/facebook'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'accessToken': facebookToken.tokenString,
        'tokenType': facebookToken.type.name,
        'nonce': nonce,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(
        body['message'] as String? ?? 'Unable to sign in to Wicchu.',
      );
    }

    return _saveSession(body);
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
  }) async {
    await _postAuth('/api/auth/register', {
      'name': name.trim(),
      'userName': userName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    }, successCodes: const {201});
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _postAuth('/api/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    });
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
        key: AuthenticatedApiClient.accessTokenKey,
        value: session.accessToken,
      ),
      _storage.write(
        key: AuthenticatedApiClient.refreshTokenKey,
        value: session.refreshToken,
      ),
    ]);
    return session;
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      FacebookAuth.instance.logOut(),
      GoogleSignIn.instance.signOut(),
      _storage.delete(key: AuthenticatedApiClient.accessTokenKey),
      _storage.delete(key: AuthenticatedApiClient.refreshTokenKey),
    ]);
  }

  String _createNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(sha256.convert(bytes).bytes).replaceAll('=', '');
  }
}
