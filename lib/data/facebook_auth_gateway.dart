import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/auth_gateway.dart';

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

  static const _accessTokenKey = 'wicchu_access_token';
  static const _refreshTokenKey = 'wicchu_refresh_token';

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _apiBaseUrl;

  @override
  Future<bool> hasSession() async =>
      (await _storage.read(key: _refreshTokenKey))?.isNotEmpty == true;

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

    final session = AuthSession(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      userId: body['userId'] as String,
      userName: body['userName'] as String,
      isNewUser: body['isNewUser'] as bool? ?? false,
    );
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
    ]);
    return session;
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      FacebookAuth.instance.logOut(),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  String _createNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(sha256.convert(bytes).bytes).replaceAll('=', '');
  }
}
