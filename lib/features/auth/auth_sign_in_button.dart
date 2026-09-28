import 'package:flutter/material.dart';
import '../../localization/app_language.dart';

class AuthSignInButton extends StatelessWidget {
  const AuthSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    this.filled = false,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.disabled = false,
  });
  final String label;
  final VoidCallback onPressed;
  final Widget icon;
  final bool filled, isLoading, disabled;
  final Color? backgroundColor, foregroundColor;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                : Opacity(opacity: disabled ? .4 : 1, child: icon),
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
              onPressed: disabled ? null : onPressed,
              child: content,
            )
          : OutlinedButton(
              style: style,
              onPressed: disabled ? null : onPressed,
              child: content,
            ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.disabled = false,
  });
  final VoidCallback onPressed;
  final bool isLoading, disabled;
  @override
  Widget build(BuildContext context) => AuthSignInButton(
    label: 'Continue with Google',
    onPressed: onPressed,
    isLoading: isLoading,
    disabled: disabled,
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
  );
}

class FacebookSignInButton extends StatelessWidget {
  const FacebookSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.disabled = false,
  });
  final VoidCallback onPressed;
  final bool isLoading, disabled;
  @override
  Widget build(BuildContext context) => AuthSignInButton(
    label: 'Continue with Facebook',
    onPressed: onPressed,
    isLoading: isLoading,
    disabled: disabled,
    icon: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 24),
  );
}
