import 'package:flutter/material.dart';

import 'data/demo_community_repository.dart';
import 'domain/auth_gateway.dart';
import 'main.dart';

void main() {
  runApp(
    WicchuApp(
      repository: DemoCommunityRepository(),
      authGateway: _PreviewAuthGateway(),
    ),
  );
}

class _PreviewAuthGateway implements AuthGateway {
  @override
  Future<bool> hasSession() async => true;

  @override
  Future<AuthSession> signInWithFacebook() =>
      throw UnimplementedError('Facebook login is unavailable in the preview.');

  @override
  Future<AuthSession> signInWithGoogle() =>
      throw UnimplementedError('Google login is unavailable in the preview.');

  @override
  Future<AuthSession> signInWithEmail(String email, String password) =>
      throw UnimplementedError('Email login is unavailable in the preview.');

  @override
  Future<void> registerWithEmail({
    required String name,
    required String userName,
    required String email,
    required String password,
    required String locale,
  }) => throw UnimplementedError(
    'Email registration is unavailable in the preview.',
  );

  @override
  Future<void> resendVerificationEmail(
    String email, {
    required String locale,
  }) => throw UnimplementedError(
    'Email verification is unavailable in the preview.',
  );

  @override
  Future<void> requestPasswordReset(String email) =>
      throw UnimplementedError('Password reset is unavailable in the preview.');

  @override
  Future<void> signOut() async {}
}
