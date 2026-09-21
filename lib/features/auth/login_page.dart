import 'package:flutter/material.dart';

import '../../domain/auth_gateway.dart';

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
  bool _loading = false;

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
                  Icon(
                    Icons.people_alt_rounded,
                    size: 76,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Wicchu',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tu comunidad, más cerca.',
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
                      onPressed: _loading ? null : _signIn,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.facebook),
                      label: const Text('Continue with Facebook'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'By continuing, you agree to Wicchu’s Terms and Privacy Policy.',
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

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await widget.authGateway.signInWithFacebook();
      widget.onSignedIn();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facebook sign-in is unavailable.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
