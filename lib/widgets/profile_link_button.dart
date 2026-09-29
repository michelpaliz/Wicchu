import 'package:flutter/material.dart';

String profileLinkNetwork(String url) {
  final uri = Uri.tryParse(url);
  if (uri?.scheme == 'mailto') return 'email';
  final host = uri?.host.toLowerCase() ?? '';
  bool matches(String domain) => host == domain || host.endsWith('.$domain');
  if (matches('wa.me') || matches('whatsapp.com')) return 'whatsapp';
  if (matches('facebook.com') || matches('fb.me')) return 'facebook';
  if (matches('instagram.com')) return 'instagram';
  if (matches('t.me') || matches('telegram.me') || matches('telegram.org')) {
    return 'telegram';
  }
  if (matches('youtube.com') || matches('youtu.be')) return 'youtube';
  return 'website';
}

class ProfileLinkButton extends StatelessWidget {
  const ProfileLinkButton({
    super.key,
    required this.network,
    required this.onTap,
    this.label,
  });
  final String network;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (defaultLabel, icon, brandColor) = switch (network) {
      'whatsapp' => ('WhatsApp', Icons.chat_outlined, const Color(0xFF128C7E)),
      'facebook' => ('Facebook', Icons.facebook, const Color(0xFF1877F2)),
      'instagram' => (
        'Instagram',
        Icons.camera_alt_outlined,
        const Color(0xFFC13584),
      ),
      'email' => (
        'Email',
        Icons.mail_outline,
        Theme.of(context).colorScheme.primary,
      ),
      'telegram' => ('Telegram', Icons.send_outlined, const Color(0xFF0088CC)),
      'youtube' => (
        'YouTube',
        Icons.play_circle_outline,
        const Color(0xFFCC0000),
      ),
      _ => ('Website', Icons.language, Theme.of(context).colorScheme.primary),
    };
    final label = this.label ?? defaultLabel;
    final theme = Theme.of(context);
    final foreground = theme.brightness == Brightness.dark
        ? Color.lerp(brandColor, Colors.white, .35)!
        : brandColor;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(
                      alpha: theme.brightness == Brightness.dark ? .20 : .09,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
