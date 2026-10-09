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
};

Color profileAccentColor(String value) =>
    _profileAccentColors[value] ?? _profileAccentColors['teal']!;

String profileAccentLabel(String value) => switch (value) {
  'blue' => 'Blue',
  'indigo' => 'Indigo',
  'purple' => 'Purple',
  'rose' => 'Rose',
  'orange' => 'Orange',
  'green' => 'Green',
  'slate' => 'Slate',
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
                  ? const Icon(WicchuIcons.check, color: Colors.white, size: 22)
                  : null,
            ),
          ),
        ),
    ],
  );
}
