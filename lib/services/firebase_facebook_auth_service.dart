import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseFacebookAuthResult {
  const FirebaseFacebookAuthResult({required this.idToken});

  final String idToken;
}

class FirebaseFacebookAuthFailure implements Exception {
  const FirebaseFacebookAuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract interface class FirebaseFacebookAuthenticator {
  Future<FirebaseFacebookAuthResult> authenticate(String facebookAccessToken);
}

class DefaultFirebaseFacebookAuthenticator
    implements FirebaseFacebookAuthenticator {
  DefaultFirebaseFacebookAuthenticator({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  static const _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '414702659593-94b8of4j0mgj16pr0r13a6a1dpm9mvpu.apps.googleusercontent.com',
  );
  static const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  @override
  Future<FirebaseFacebookAuthResult> authenticate(
    String facebookAccessToken,
  ) async {
    try {
      await _ensureFirebaseInitialized();
    } on FirebaseFacebookAuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
      developer.log(
        'Firebase initialization error code=${error.code} '
        'message=${error.message ?? 'none'}',
        name: 'wicchu.facebook_auth',
      );
      throw FirebaseFacebookAuthFailure(
        error.code,
        error.message ?? 'Firebase Authentication could not initialize.',
      );
    } catch (error) {
      developer.log(
        'Firebase initialization exception: ${error.runtimeType}',
        name: 'wicchu.facebook_auth',
      );
      throw const FirebaseFacebookAuthFailure(
        'firebase-initialization-failed',
        'Firebase Authentication could not initialize.',
      );
    }
    final facebookCredential = FacebookAuthProvider.credential(
      facebookAccessToken,
    );
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(
        facebookCredential,
      );
      return FirebaseFacebookAuthResult(
        idToken: await _requiredIdToken(result.user),
      );
    } on FirebaseAuthException catch (error) {
      _logFirebaseError('facebook_sign_in', error);
      if (error.code != 'account-exists-with-different-credential') {
        throw FirebaseFacebookAuthFailure(
          error.code,
          error.message ?? 'Firebase could not authenticate Facebook.',
        );
      }
      return _linkFacebookToGoogle(
        facebookCredential: facebookCredential,
        expectedEmail: error.email,
      );
    }
  }

  Future<FirebaseFacebookAuthResult> _linkFacebookToGoogle({
    required AuthCredential facebookCredential,
    required String? expectedEmail,
  }) async {
    try {
      _googleInitialization ??= _googleSignIn.initialize(
        clientId: kIsWeb ? _googleWebClientId : null,
        serverClientId: _googleWebClientId,
      );
      await _googleInitialization;
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const FirebaseFacebookAuthFailure(
          'google-link-unavailable',
          'Sign in with Google first to connect this Facebook account.',
        );
      }
      final googleAccount = await _googleSignIn.authenticate();
      if (expectedEmail != null &&
          expectedEmail.isNotEmpty &&
          googleAccount.email.toLowerCase() != expectedEmail.toLowerCase()) {
        throw const FirebaseFacebookAuthFailure(
          'google-link-email-mismatch',
          'Choose the Google account that uses the same email as Facebook.',
        );
      }
      final googleIdToken = googleAccount.authentication.idToken;
      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw const FirebaseFacebookAuthFailure(
          'google-link-token-missing',
          'Google did not return an identity token for account linking.',
        );
      }
      final googleCredential = GoogleAuthProvider.credential(
        idToken: googleIdToken,
      );
      final googleResult = await FirebaseAuth.instance.signInWithCredential(
        googleCredential,
      );
      final user = googleResult.user;
      if (user == null) {
        throw const FirebaseFacebookAuthFailure(
          'google-link-user-missing',
          'Firebase could not load the Google account for linking.',
        );
      }
      try {
        await user.linkWithCredential(facebookCredential);
      } on FirebaseAuthException catch (error) {
        _logFirebaseError('facebook_link', error);
        if (error.code != 'provider-already-linked') {
          throw FirebaseFacebookAuthFailure(
            error.code,
            error.message ?? 'Firebase could not link Facebook to Google.',
          );
        }
      }
      return FirebaseFacebookAuthResult(
        idToken: await _requiredIdToken(FirebaseAuth.instance.currentUser),
      );
    } on FirebaseFacebookAuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      _logFirebaseError('google_link_sign_in', error);
      throw FirebaseFacebookAuthFailure(
        error.code,
        error.message ?? 'Firebase could not link Facebook to Google.',
      );
    } catch (error) {
      developer.log(
        'Facebook/Google linking exception: ${error.runtimeType}',
        name: 'wicchu.facebook_auth',
      );
      throw const FirebaseFacebookAuthFailure(
        'facebook-google-link-failed',
        'Could not connect Facebook to the existing Google account.',
      );
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    if (kIsWeb) {
      if (_firebaseApiKey.isEmpty ||
          _firebaseAppId.isEmpty ||
          _firebaseSenderId.isEmpty ||
          _firebaseProjectId.isEmpty) {
        throw const FirebaseFacebookAuthFailure(
          'firebase-not-configured',
          'Firebase Authentication is not configured for this platform.',
        );
      }
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _firebaseApiKey,
          appId: _firebaseAppId,
          messagingSenderId: _firebaseSenderId,
          projectId: _firebaseProjectId,
        ),
      );
      return;
    }
    await Firebase.initializeApp();
  }

  Future<String> _requiredIdToken(User? user) async {
    final token = await user?.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const FirebaseFacebookAuthFailure(
        'firebase-id-token-missing',
        'Firebase did not return an identity token.',
      );
    }
    return token;
  }

  void _logFirebaseError(String stage, FirebaseAuthException error) {
    developer.log(
      'FirebaseAuthException stage=$stage code=${error.code} '
      'message=${error.message ?? 'none'}',
      name: 'wicchu.facebook_auth',
    );
  }
}
