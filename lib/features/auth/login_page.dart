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
                  _signInButton(
                    provider: 'google',
                    label: 'Continue with Google',
                    onPressed: _signInGoogle,
                    filled: true,
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _signInButton(
                    provider: 'facebook',
                    label: 'Continue with Facebook',
                    onPressed: _signInFacebook,
                    icon: const Icon(
                      Icons.facebook,
                      color: Color(0xFF1877F2),
                      size: 24,
                    ),
                  ),
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
  }) {
    final colors = Theme.of(context).colorScheme;
    final isLoading = _loadingProvider == provider;
    final foreground =
        foregroundColor ?? (filled ? colors.onPrimary : colors.onSurface);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 54)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !isLoading) {
          return colors.onSurface.withValues(alpha: .38);
        }
        return foreground;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (filled) {
          return states.contains(WidgetState.disabled) && !isLoading
              ? colors.onSurface.withValues(alpha: .12)
              : (backgroundColor ?? colors.primary);
        }
        return colors.surface;
      }),
      side: WidgetStatePropertyAll(
        filled ? BorderSide.none : BorderSide(color: colors.outlineVariant),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
      ),
    );
    final content = Row(
      children: [
        SizedBox.square(
          dimension: 24,
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Opacity(
                    opacity: _loadingProvider != null ? .4 : 1,
                    child: icon,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr(isLoading ? 'Signing in…' : label),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 36),
      ],
    );
    return Semantics(
      liveRegion: isLoading,
      child: filled
          ? FilledButton(
              style: style,
              onPressed: _loadingProvider == null ? onPressed : null,
              child: content,
            )
          : OutlinedButton(
              style: style,
              onPressed: _loadingProvider == null ? onPressed : null,
              child: content,
            ),
    );
  }

  Future<void> _signInFacebook() => _signIn(
    provider: 'facebook',
    action: widget.authGateway.signInWithFacebook,
    unavailableMessage:
        'Facebook sign-in will be available soon. In the meantime, use Google or email and password.',
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
        final facebookFailed =
            provider == 'facebook' &&
            error.message != 'Facebook sign-in was cancelled.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              facebookFailed
                  ? context.tr(unavailableMessage)
                  : context.trError(error),
            ),
            duration: Duration(seconds: facebookFailed ? 7 : 4),
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
