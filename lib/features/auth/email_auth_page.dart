import 'auth_sign_in_button.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/auth_gateway.dart';
import '../../localization/app_language.dart';

class EmailAuthPage extends StatefulWidget {
  const EmailAuthPage({
    super.key,
    required this.authGateway,
    required this.onSignedIn,
  });

  final AuthGateway authGateway;
  final VoidCallback onSignedIn;

  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _userName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _registering = false;
  bool _resetting = false;
  String? _error;
  bool _resetSent = false;
  bool _verificationResent = false;
  bool _loading = false;
  String? _socialProvider;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _name.dispose();
    _userName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(
          _resetting
              ? 'Reset password'
              : _registering
              ? 'Create account'
              : 'Sign in with email',
        ),
      ),
      leading: _resetting
          ? BackButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _resetting = false;
                      _error = null;
                      _resetSent = false;
                    }),
            )
          : null,
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr(
                        _resetting
                            ? 'Recover access to your account'
                            : _registering
                            ? 'Welcome to Wicchu'
                            : 'Welcome back',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        _resetting
                            ? 'Enter your email and we will send you a reset link.'
                            : _registering
                            ? 'Connect with communities and people around you.'
                            : 'Stay connected with the communities and people that matter to you.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_resetting)
                      SegmentedButton<bool>(
                        style: ButtonStyle(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(0, 48),
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(context.tr('Sign in')),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text(context.tr('Register')),
                          ),
                        ],
                        selected: {_registering},
                        onSelectionChanged: _loading
                            ? null
                            : (selection) => setState(() {
                                _registering = selection.first;
                                _error = null;
                                _formKey.currentState?.reset();
                              }),
                      ),
                    const SizedBox(height: 24),
                    if (_registering && !_resetting) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        enabled: !_loading,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline),
                          labelText: context.tr('Full name'),
                        ),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? context.tr('Enter your name.')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _userName,
                        textInputAction: TextInputAction.next,
                        enabled: !_loading,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.newUsername],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.alternate_email),
                          labelText: context.tr('Username'),
                        ),
                        validator: (value) {
                          final normalized = value?.trim() ?? '';
                          if (normalized.length < 3) {
                            return context.tr('Use at least 3 characters.');
                          }
                          if (!RegExp(
                            r'^[a-zA-Z0-9._-]+$',
                          ).hasMatch(normalized)) {
                            return context.tr(
                              'Use only letters, numbers, dots, underscores, or hyphens.',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      textInputAction: _resetting
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onFieldSubmitted: _resetting ? (_) => _submit() : null,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.mail_outline),
                        labelText: context.tr('Email address'),
                      ),
                      validator: (value) =>
                          RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value?.trim() ?? '')
                          ? null
                          : context.tr('Enter a valid email address.'),
                    ),
                    if (!_resetting) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        onChanged: (_) => setState(() {}),
                        enabled: !_loading,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: _registering
                            ? TextInputAction.next
                            : TextInputAction.done,
                        obscureText: _obscurePassword,
                        autofillHints: [
                          _registering
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          labelText: context.tr('Password'),
                          suffixIcon: IconButton(
                            tooltip: context.tr(
                              _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                            onPressed: _loading
                                ? null
                                : () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => _registering
                            ? ((value?.length ?? 0) < 8
                                  ? context.tr(
                                      'Password must be at least 8 characters.',
                                    )
                                  : null)
                            : ((value?.isEmpty ?? true)
                                  ? context.tr('Enter your password.')
                                  : null),
                        onFieldSubmitted: (_) {
                          if (!_registering) _submit();
                        },
                      ),
                      if (_registering && !_resetting) ...[
                        const SizedBox(height: 10),
                        _passwordFeedback(),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _confirmPassword,
                          onChanged: (_) => setState(() {}),
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          enabled: !_loading,
                          obscureText: _obscureConfirmation,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: context.tr(
                                _obscureConfirmation
                                    ? 'Show password'
                                    : 'Hide password',
                              ),
                              onPressed: _loading
                                  ? null
                                  : () => setState(
                                      () => _obscureConfirmation =
                                          !_obscureConfirmation,
                                    ),
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            helperText: _confirmPassword.text.isEmpty
                                ? null
                                : context.tr(
                                    _confirmPassword.text == _password.text
                                        ? 'Passwords match'
                                        : 'Passwords do not match.',
                                  ),
                            helperStyle: TextStyle(
                              color: _confirmPassword.text == _password.text
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                            ),
                            labelText: context.tr('Confirm password'),
                          ),
                          validator: (value) => value == _password.text
                              ? null
                              : context.tr('Passwords do not match.'),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ],
                    if (!_registering && !_resetting)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _loading ? null : _resendVerification,
                            child: Text(context.tr('Resend verification')),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                    _resetting = true;
                                    _error = null;
                                    _verificationResent = false;
                                  }),
                            child: Text(context.tr('Forgot password?')),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_resetSent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          context.tr(
                            'If an account exists, a password reset email has been sent.',
                          ),
                        ),
                      ),
                    if (_verificationResent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          context.tr(
                            'If an account exists, a verification email has been sent.',
                          ),
                        ),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.tr(
                                _resetting
                                    ? 'Send reset link'
                                    : _registering
                                    ? 'Create account'
                                    : 'Sign in',
                              ),
                            ),
                    ),
                    if (_registering && !_resetting) ...[
                      const SizedBox(height: 16),
                      Text(
                        context.tr(
                          'By creating an account, you agree to Wicchu’s',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => _openPolicy('terms'),
                            child: Text(context.tr('Terms of Service')),
                          ),
                          TextButton(
                            onPressed: () => _openPolicy('privacy'),
                            child: Text(context.tr('Privacy Policy')),
                          ),
                        ],
                      ),
                    ],
                    if (!_resetting && !_registering) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(context.tr('or')),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GoogleSignInButton(
                        onPressed: () => _socialSignIn(false),
                        isLoading: _socialProvider == 'google',
                        disabled: _loading,
                      ),
                      const SizedBox(height: 10),
                      FacebookSignInButton(
                        onPressed: () => _socialSignIn(true),
                        isLoading: _socialProvider == 'facebook',
                        disabled: _loading,
                      ),
                      const SizedBox(height: 28),
                      Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Icon(
                            Icons.groups_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            context.tr('New to Wicchu?'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            context.tr(
                              'Create an account and start exploring.',
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: _loading
                              ? null
                              : () => setState(() {
                                  _registering = true;
                                  _error = null;
                                  _formKey.currentState?.reset();
                                }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _openPolicy(String page) async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://hexora.dev/wicchu/$page'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Could not open the page. Please try again.'),
            ),
          ),
        );
      }
    }
  }

  Widget _passwordFeedback() {
    final password = _password.text;
    final score = [
      password.length >= 8,
      password.length >= 12,
      RegExp(r'[a-zA-Z]').hasMatch(password) &&
          RegExp(r'[0-9]').hasMatch(password),
      RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
    ].where((v) => v).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: password.isEmpty ? 0 : score / 4,
          minHeight: 5,
          borderRadius: BorderRadius.circular(5),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(
            password.isEmpty
                ? 'At least 8 characters'
                : score >= 3
                ? 'Strong password'
                : score >= 2
                ? 'Medium password strength'
                : 'Weak password',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _socialSignIn(bool facebook) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _socialProvider = facebook ? 'facebook' : 'google';
      _error = null;
    });
    try {
      await (facebook
          ? widget.authGateway.signInWithFacebook()
          : widget.authGateway.signInWithGoogle());
      if (mounted) widget.onSignedIn();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              facebook &&
                  !(error is AuthException &&
                      error.message == 'Facebook sign-in was cancelled.')
              ? context.tr(
                  'Facebook sign-in will be available soon. In the meantime, use Google or email and password.',
                )
              : context.trError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _socialProvider = null;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_resetting) {
        await widget.authGateway.requestPasswordReset(_email.text.trim());
        if (mounted) setState(() => _resetSent = true);
      } else if (_registering) {
        await widget.authGateway.registerWithEmail(
          name: _name.text,
          userName: _userName.text,
          email: _email.text.trim(),
          password: _password.text,
          locale: Localizations.localeOf(context).languageCode,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.mark_email_read_outlined),
            title: Text(dialogContext.tr('Check your email')),
            content: Text(
              dialogContext.tr(
                'We sent you a verification link. Verify your email before signing in.',
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.tr('Done')),
              ),
            ],
          ),
        );
        if (!mounted) return;
        _password.clear();
        _confirmPassword.clear();
        setState(() => _registering = false);
      } else {
        await widget.authGateway.signInWithEmail(
          _email.text.trim(),
          _password.text,
        );
        widget.onSignedIn();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is AuthException &&
              error.code == 'EMAIL_ALREADY_REGISTERED') {
            _registering = false;
            _error = context.tr(
              'This email already has an account. Sign in below or reset your password.',
            );
          } else {
            _error = context.trError(error);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendVerification() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = context.tr('Enter a valid email address.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _verificationResent = false;
    });
    try {
      await widget.authGateway.resendVerificationEmail(
        email,
        locale: Localizations.localeOf(context).languageCode,
      );
      if (mounted) setState(() => _verificationResent = true);
    } catch (error) {
      if (mounted) setState(() => _error = context.trError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
