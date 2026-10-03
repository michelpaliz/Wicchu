import 'auth_sign_in_button.dart';
import 'package:flutter/foundation.dart';
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
                  const WicchuLogo(size: 88),
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
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Connect with your neighbors and discover what is happening nearby.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  GoogleSignInButton(
                    onPressed: _signInGoogle,
                    isLoading: _loadingProvider == 'google',
                    disabled: _loadingProvider != null,
                  ),
                  const SizedBox(height: 12),
                  FacebookSignInButton(
                    onPressed: _signInFacebook,
                    isLoading: _loadingProvider == 'facebook',
                    disabled: _loadingProvider != null,
                  ),
                  if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                    const SizedBox(height: 12),
                    _signInButton(
                      provider: 'apple',
                      label: 'Continue with Apple',
                      onPressed: _signInApple,
                      icon: const Icon(Icons.apple, size: 24),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      filled: true,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            context.tr('or'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  _signInButton(
                    provider: 'email',
                    label: 'Continue with email',
                    onPressed: _openEmail,
                    icon: const Icon(Icons.mail_outline_rounded, size: 22),
                    filled: true,
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

  Widget _signInButton({
    required String provider,
    required String label,
    required VoidCallback onPressed,
    required Widget icon,
    bool filled = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) => AuthSignInButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    filled: filled,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    isLoading: _loadingProvider == provider,
    disabled: _loadingProvider != null,
  );

  Future<void> _openEmail() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (emailContext) => EmailAuthPage(
          authGateway: widget.authGateway,
          onSignedIn: () => Navigator.of(emailContext).pop(true),
        ),
      ),
    );
    if (signedIn == true && mounted) widget.onSignedIn();
  }

  Future<void> _signInGoogle() => _signIn(
    provider: 'google',
    action: widget.authGateway.signInWithGoogle,
    unavailableMessage: 'Google sign-in is unavailable.',
  );

  Future<void> _signInFacebook() => _signIn(
    provider: 'facebook',
    action: widget.authGateway.signInWithFacebook,
    unavailableMessage: 'Facebook sign-in is unavailable.',
  );

  Future<void> _signInApple() => _signIn(
    provider: 'apple',
    action: widget.authGateway.signInWithApple,
    unavailableMessage: 'Apple sign-in is unavailable.',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.trError(error)),
            duration: Duration(seconds: provider == 'facebook' ? 7 : 4),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(unavailableMessage)),
            duration: Duration(seconds: provider == 'facebook' ? 7 : 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }
}
