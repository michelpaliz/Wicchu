import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

const profileAccentKeys = <String>[
  'teal',
  'blue',
  'indigo',
  'purple',
  'rose',
  'orange',
  'green',
  'slate',
  'neon_cyan',
  'neon_lime',
  'neon_pink',
  'neon_violet',
  'neon_orange',
];

const _profileAccentColors = <String, Color>{
  'teal': Color(0xff087f6b),
  'blue': Color(0xff2563eb),
  'indigo': Color(0xff4f46e5),
  'purple': Color(0xff9333ea),
  'rose': Color(0xffe11d48),
  'orange': Color(0xffea580c),
  'green': Color(0xff15803d),
  'slate': Color(0xff475569),
  'neon_cyan': Color(0xff00e5ff),
  'neon_lime': Color(0xffb7ff00),
  'neon_pink': Color(0xffff2bd6),
  'neon_violet': Color(0xff7c3cff),
  'neon_orange': Color(0xffff6d00),
};

Color profileAccentColor(String value) =>
    _profileAccentColors[value] ?? _profileAccentColors['teal']!;

List<BoxShadow> profileNeonGlow(String value) {
  final color = profileAccentColor(value);
  return [
    BoxShadow(
      color: color.withValues(alpha: .58),
      blurRadius: 14,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: color.withValues(alpha: .28),
      blurRadius: 28,
      spreadRadius: 3,
    ),
  ];
}

Color profileAccentOnColor(String value) =>
    profileAccentColor(value).computeLuminance() > .48
    ? Colors.black
    : Colors.white;

Color profileAccentForegroundColor(String value, Brightness brightness) {
  if (brightness == Brightness.dark) return profileAccentColor(value);
  return switch (value) {
    'neon_cyan' => const Color(0xff007c91),
    'neon_lime' => const Color(0xff4d7c0f),
    'neon_pink' => const Color(0xffc2188b),
    'neon_violet' => const Color(0xff6d28d9),
    'neon_orange' => const Color(0xffc2410c),
    _ => profileAccentColor(value),
  };
}

String profileAccentLabel(String value) => switch (value) {
  'blue' => 'Blue',
  'indigo' => 'Indigo',
  'purple' => 'Purple',
  'rose' => 'Rose',
  'orange' => 'Orange',
  'green' => 'Green',
  'slate' => 'Slate',
  'neon_cyan' => 'Neon cyan',
  'neon_lime' => 'Neon lime',
  'neon_pink' => 'Neon pink',
  'neon_violet' => 'Neon violet',
  'neon_orange' => 'Neon orange',
  _ => 'Teal',
};

class ProfileAccentPicker extends StatelessWidget {
  const ProfileAccentPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelBuilder,
  });

  final String value;
  final ValueChanged<String>? onChanged;
  final String Function(String value)? labelBuilder;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final key in profileAccentKeys)
        Semantics(
          button: true,
          selected: value == key,
          label: labelBuilder?.call(key) ?? profileAccentLabel(key),
          child: InkWell(
            key: ValueKey('profile-accent-$key'),
            onTap: onChanged == null ? null : () => onChanged!(key),
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: profileAccentColor(key),
                shape: BoxShape.circle,
                border: Border.all(
                  color: value == key
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: value == key
                  ? Icon(
                      WicchuIcons.check,
                      color: profileAccentOnColor(key),
                      size: 22,
                    )
                  : null,
            ),
          ),
        ),
    ],
  );
}
