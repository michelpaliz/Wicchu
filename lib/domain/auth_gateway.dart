class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.userName,
    required this.isNewUser,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String userName;
  final bool isNewUser;
}

abstract interface class AuthGateway {
  Future<bool> hasSession();
  Future<AuthSession> signInWithFacebook();
  Future<AuthSession> signInWithGoogle();
  Future<AuthSession> signInWithEmail(String email, String password);
  Future<void> registerWithEmail({
    required String name,
    required String userName,
    required String email,
    required String password,
  });
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
