import 'dart:convert';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wicchu/data/facebook_auth_gateway.dart';
import 'package:wicchu/services/firebase_facebook_auth_service.dart';

class _RecordingFirebaseAuthenticator implements FirebaseFacebookAuthenticator {
  String? receivedAccessToken;

  @override
  Future<FirebaseFacebookAuthResult> authenticate(
    String facebookAccessToken,
  ) async {
    receivedAccessToken = facebookAccessToken;
    return const FirebaseFacebookAuthResult(idToken: 'firebase-id-token');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Facebook authenticates with Firebase before creating Wicchu session',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final firebase = _RecordingFirebaseAuthenticator();
      Map<String, dynamic>? requestBody;
      final client = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'accessToken': 'wicchu-access',
            'refreshToken': 'wicchu-refresh',
            'userId': 'user-1',
            'userName': 'facebook_user',
            'isNewUser': false,
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final gateway = FacebookAuthGateway(
        client: client,
        apiBaseUrl: 'https://example.test',
        firebaseFacebookAuthenticator: firebase,
        facebookLogin: (_) async => LoginResult(
          status: LoginStatus.success,
          accessToken: ClassicToken(
            declinedPermissions: const [],
            grantedPermissions: const ['email', 'public_profile'],
            userId: 'facebook-user',
            expires: DateTime.now().add(const Duration(hours: 1)),
            tokenString: 'facebook-access-token',
            applicationId: '1526807682821937',
          ),
        ),
      );

      final session = await gateway.signInWithFacebook();

      expect(firebase.receivedAccessToken, 'facebook-access-token');
      expect(requestBody?['firebaseIdToken'], 'firebase-id-token');
      expect(requestBody?['accessToken'], 'facebook-access-token');
      expect(requestBody?['tokenType'], 'classic');
      expect(session.accessToken, 'wicchu-access');
      expect(session.userId, 'user-1');
    },
  );

  test('Firebase failures stop the Wicchu backend request', () async {
    FlutterSecureStorage.setMockInitialValues({});
    var backendCalled = false;
    final gateway = FacebookAuthGateway(
      client: MockClient((_) async {
        backendCalled = true;
        return http.Response('{}', 500);
      }),
      firebaseFacebookAuthenticator: _FailingFirebaseAuthenticator(),
      facebookLogin: (_) async => LoginResult(
        status: LoginStatus.success,
        accessToken: ClassicToken(
          declinedPermissions: const [],
          grantedPermissions: const ['email'],
          userId: 'facebook-user',
          expires: DateTime.now().add(const Duration(hours: 1)),
          tokenString: 'facebook-access-token',
          applicationId: '1526807682821937',
        ),
      ),
    );

    await expectLater(
      gateway.signInWithFacebook(),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Firebase Facebook provider is disabled'),
        ),
      ),
    );
    expect(backendCalled, isFalse);
  });

  test('signed-in users can securely link Facebook', () async {
    FlutterSecureStorage.setMockInitialValues({
      'wicchu_access_token': 'wicchu-access',
      'wicchu_refresh_token': 'wicchu-refresh',
    });
    final firebase = _RecordingFirebaseAuthenticator();
    Map<String, dynamic>? requestBody;
    String? authorization;
    final gateway = FacebookAuthGateway(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/facebook/link');
        authorization = request.headers['authorization'];
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'facebook': true}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
      apiBaseUrl: 'https://example.test',
      firebaseFacebookAuthenticator: firebase,
      facebookLogin: (_) async => LoginResult(
        status: LoginStatus.success,
        accessToken: ClassicToken(
          declinedPermissions: const [],
          grantedPermissions: const ['email', 'public_profile'],
          userId: 'facebook-user',
          expires: DateTime.now().add(const Duration(hours: 1)),
          tokenString: 'facebook-access-token',
          applicationId: '1526807682821937',
        ),
      ),
    );

    await gateway.linkFacebookAccount();

    expect(authorization, 'Bearer wicchu-access');
    expect(requestBody?['accessToken'], 'facebook-access-token');
    expect(requestBody?['firebaseIdToken'], 'firebase-id-token');
  });
}

class _FailingFirebaseAuthenticator implements FirebaseFacebookAuthenticator {
  @override
  Future<FirebaseFacebookAuthResult> authenticate(String facebookAccessToken) =>
      throw const FirebaseFacebookAuthFailure(
        'operation-not-allowed',
        'Firebase Facebook provider is disabled.',
      );
}
