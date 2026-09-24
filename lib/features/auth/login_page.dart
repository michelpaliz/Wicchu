import 'package:flutter/material.dart';

import '../../domain/auth_gateway.dart';
import '../../localization/app_language.dart';
import '../../theme/theme_menu.dart';
import '../../widgets/wicchu_logo.dart';
import 'email_auth_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authGateway,
    required this.onSignedIn,
  });

  final AuthGateway authGateway;
  final VoidCallback onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _loadingProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [ThemeMenu(), LanguageMenu()],
                  ),
                  const SizedBox(height: 24),
                  const WicchuLogo(size: 112),
                  const SizedBox(height: 20),
                  Text(
                    'Wicchu',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('Your community, closer.'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1877F2),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _loadingProvider != null
                          ? null
                          : _signInFacebook,
                      icon: _loadingProvider == 'facebook'
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.facebook),
                      label: Text(context.tr('Continue with Facebook')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loadingProvider != null ? null : _openEmail,
                      icon: const Icon(Icons.email_outlined),
                      label: Text(context.tr('Continue with email')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loadingProvider != null
                          ? null
                          : _signInGoogle,
                      icon: _loadingProvider == 'google'
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                      label: Text(context.tr('Continue with Google')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr(
                      'By continuing, you agree to Wicchu’s Terms and Privacy Policy.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInFacebook() => _signIn(
    provider: 'facebook',
    action: widget.authGateway.signInWithFacebook,
    unavailableMessage: 'Facebook sign-in is unavailable.',
  );

  Future<void> _openEmail() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailAuthPage(
          authGateway: widget.authGateway,
          onSignedIn: widget.onSignedIn,
        ),
      ),
    );
  }

  Future<void> _signInGoogle() => _signIn(
    provider: 'google',
    action: widget.authGateway.signInWithGoogle,
    unavailableMessage: 'Google sign-in is unavailable.',
  );

  Future<void> _signIn({
    required String provider,
    required Future<AuthSession> Function() action,
    required String unavailableMessage,
  }) async {
    setState(() => _loadingProvider = provider);
    try {
      await action();
      widget.onSignedIn();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr(unavailableMessage))));
      }
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }
}
