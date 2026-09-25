import 'package:flutter/material.dart';

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
  bool _obscurePassword = true;

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
                            ? 'Join your neighborhood'
                            : 'Welcome back',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        _resetting
                            ? 'Enter your email and we will send you a reset link.'
                            : 'Connect with your neighbors and discover what is happening nearby.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_resetting)
                      SegmentedButton<bool>(
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
                          labelText: context.tr('Password'),
                          helperText: _registering
                              ? context.tr('At least 8 characters')
                              : null,
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
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPassword,
                          enabled: !_loading,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

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
      if (mounted) setState(() => _error = context.trError(error));
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
