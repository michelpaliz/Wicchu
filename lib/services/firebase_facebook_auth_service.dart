import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
  Future<FirebaseFacebookAuthResult> authenticate({
    required String facebookToken,
    required String tokenType,
    required String nonce,
    String? existingGoogleIdToken,
  });
}

class DefaultFirebaseFacebookAuthenticator
    implements FirebaseFacebookAuthenticator {
  DefaultFirebaseFacebookAuthenticator();

  static const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  @override
  Future<FirebaseFacebookAuthResult> authenticate({
    required String facebookToken,
    required String tokenType,
    required String nonce,
    String? existingGoogleIdToken,
  }) async {
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
    final AuthCredential facebookCredential;
    if (tokenType == 'limited') {
      if (nonce.isEmpty) {
        throw const FirebaseFacebookAuthFailure(
          'facebook-nonce-missing',
          'Facebook Limited Login did not return a valid nonce.',
        );
      }
      facebookCredential = OAuthProvider(
        'facebook.com',
      ).credential(idToken: facebookToken, rawNonce: nonce);
    } else {
      facebookCredential = FacebookAuthProvider.credential(facebookToken);
    }
    try {
      if (existingGoogleIdToken != null && existingGoogleIdToken.isNotEmpty) {
        final googleResult = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: existingGoogleIdToken),
        );
        final googleUser = googleResult.user;
        if (googleUser == null) {
          throw const FirebaseFacebookAuthFailure(
            'firebase-user-missing',
            'Firebase could not load the Google account for linking.',
          );
        }
        try {
          await googleUser.linkWithCredential(facebookCredential);
        } on FirebaseAuthException catch (error) {
          _logFirebaseError('facebook_link', error);
          if (error.code != 'provider-already-linked') {
            throw FirebaseFacebookAuthFailure(
              error.code,
              error.message ?? 'Firebase could not connect Facebook.',
            );
          }
        }
        return FirebaseFacebookAuthResult(
          idToken: await _requiredIdToken(FirebaseAuth.instance.currentUser),
        );
      }
      final result = await FirebaseAuth.instance.signInWithCredential(
        facebookCredential,
      );
      return FirebaseFacebookAuthResult(
        idToken: await _requiredIdToken(result.user),
      );
    } on FirebaseAuthException catch (error) {
      _logFirebaseError('facebook_sign_in', error);
      if (error.code == 'account-exists-with-different-credential') {
        // The Wicchu API determines the existing provider and requires the
        // user to sign in with it before linking from authenticated Settings.
        return const FirebaseFacebookAuthResult(idToken: '');
      }
      throw FirebaseFacebookAuthFailure(
        error.code,
        error.message ?? 'Firebase could not authenticate Facebook.',
      );
    }
  }

  static Future<void> signOutIfInitialized() async {
    if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
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
