import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../localization/app_language.dart';

class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required super.child,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  static AppThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope is missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      themeMode != oldWidget.themeMode;
}

class ThemeMenu extends StatelessWidget {
  const ThemeMenu({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final selection = AppThemeScope.of(context);
    final selectedLabel = switch (selection.themeMode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
    return PopupMenuButton<ThemeMode>(
      tooltip: context.tr('Appearance'),
      onSelected: selection.onThemeChanged,
      itemBuilder: (context) => [
        for (final (mode, label) in const [
          (ThemeMode.system, 'System'),
          (ThemeMode.light, 'Light'),
          (ThemeMode.dark, 'Dark'),
        ])
          PopupMenuItem(
            value: mode,
            child: Row(
              children: [
                Expanded(child: Text(context.tr(label))),
                if (selection.themeMode == mode)
                  Icon(
                    WicchuIcons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(switch (selection.themeMode) {
              ThemeMode.system => WicchuIcons.sunDim,
              ThemeMode.light => WicchuIcons.sun,
              ThemeMode.dark => WicchuIcons.moon,
            }),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(context.tr(selectedLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
