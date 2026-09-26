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
    required String locale,
  });
  Future<void> resendVerificationEmail(String email, {required String locale});
  Future<void> requestPasswordReset(String email);
  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}
