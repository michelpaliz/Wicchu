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
      title: Text(context.tr(_registering ? 'Create account' : 'Sign in with email')),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: false, label: Text(context.tr('Sign in'))),
                        ButtonSegment(value: true, label: Text(context.tr('Register'))),
                      ],
                      selected: {_registering},
                      onSelectionChanged: _loading
                          ? null
                          : (selection) => setState(() => _registering = selection.first),
                    ),
                    const SizedBox(height: 24),
                    if (_registering) ...[
                      TextFormField(
                        controller: _name,
                        enabled: !_loading,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: InputDecoration(labelText: context.tr('Full name')),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? context.tr('Enter your name.')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _userName,
                        enabled: !_loading,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.newUsername],
                        decoration: InputDecoration(labelText: context.tr('Username')),
                        validator: (value) {
                          final normalized = value?.trim() ?? '';
                          if (normalized.length < 3) return context.tr('Use at least 3 characters.');
                          if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(normalized)) {
                            return context.tr('Use only letters, numbers, dots, underscores, or hyphens.');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: context.tr('Email address')),
                      validator: (value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value?.trim() ?? '')
                          ? null
                          : context.tr('Enter a valid email address.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      autofillHints: [_registering ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: context.tr('Password'),
                        helperText: _registering ? context.tr('At least 8 characters') : null,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? context.tr('Password must be at least 8 characters.')
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_registering) ...[
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
                    if (!_registering)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: Text(context.tr('Forgot password?')),
                        ),
                      )
                    else
                      const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr(_registering ? 'Create account' : 'Sign in')),
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
    setState(() => _loading = true);
    try {
      if (_registering) {
        await widget.authGateway.registerWithEmail(
          name: _name.text,
          userName: _userName.text,
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.mark_email_read_outlined),
            title: Text(dialogContext.tr('Check your email')),
            content: Text(dialogContext.tr('We sent you a verification link. Verify your email before signing in.')),
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
        await widget.authGateway.signInWithEmail(_email.text, _password.text);
        widget.onSignedIn();
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Reset password')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(labelText: dialogContext.tr('Email address')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(dialogContext.tr('Send reset link')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    setState(() => _loading = true);
    try {
      await widget.authGateway.requestPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('If an account exists, a password reset email has been sent.'))),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
