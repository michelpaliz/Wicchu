import '../../theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../localization/app_language.dart';
import '../../theme/theme_menu.dart';

/// The same preference controls are available before login and from Settings.
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key, this.onContinue});

  final Future<void> Function()? onContinue;

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      await widget.onContinue!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Something went wrong. Please try again.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final welcome = widget.onContinue != null;
    final language = AppLanguageScope.of(context);
    final appearance = AppThemeScope.of(context);
    final theme = Theme.of(context);
    Widget choice(
      String label,
      bool selected,
      VoidCallback onTap,
      Key key, {
      IconData? icon,
    }) => Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        minTileHeight: 50,
        minVerticalPadding: 4,
        leading: icon == null
            ? null
            : Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
        ),
        trailing: Icon(
          selected ? WicchuIcons.radioButton : WicchuIcons.circle,
          size: 22,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        onTap: _saving ? null : onTap,
      ),
    );
    Widget section(String title, String subtitle, IconData icon) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              context.tr(title),
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(subtitle),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
    return Scaffold(
      appBar: welcome
          ? null
          : AppBar(title: Text(context.tr('Language and appearance'))),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                if (welcome) ...[
                  Text(
                    context.tr('Welcome to Wicchu'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Personalize your experience. You can change these options anytime.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                ],
                section(
                  'Language',
                  'Choose the language for Wicchu.',
                  WicchuIcons.globe,
                ),
                for (final (code, name) in const [
                  ('es', 'Español'),
                  ('en', 'English'),
                ])
                  choice(
                    name,
                    language.languageCode == code,
                    () => language.onLanguageChanged(code),
                    ValueKey('language-$code'),
                  ),
                const SizedBox(height: 20),
                section(
                  'Appearance',
                  'Personalize how the app looks.',
                  WicchuIcons.palette,
                ),
                for (final (mode, label, icon) in const [
                  (
                    ThemeMode.system,
                    'Automatic (system)',
                    WicchuIcons.deviceMobile,
                  ),
                  (ThemeMode.light, 'Light', WicchuIcons.sun),
                  (ThemeMode.dark, 'Dark', WicchuIcons.moon),
                ])
                  choice(
                    context.tr(label),
                    appearance.themeMode == mode,
                    () => appearance.onThemeChanged(mode),
                    ValueKey('theme-${mode.name}'),
                    icon: icon,
                  ),
                if (!welcome) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Changes apply automatically.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (welcome) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('welcome-continue'),
                    onPressed: _saving ? null : _continue,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('Continue')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
