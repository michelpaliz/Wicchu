import 'package:flutter/material.dart';
import '../localization/app_language.dart';
import '../theme/wicchu_icons.dart';

class WicchuSearchField extends StatelessWidget {
  const WicchuSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.showSearchIcon = true,
    this.compact = false,
    this.hintText,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showSearchIcon;
  final bool compact;
  final String? hintText;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: const TextStyle(fontSize: 14),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hintText ?? context.tr('Search Wicchu…'),
      hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      prefixIcon: showSearchIcon
          ? const Icon(WicchuIcons.magnifyingGlass, size: 20)
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minHeight: 48),
      suffixIcon: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value.text.isNotEmpty)
              IconButton(
                tooltip: context.tr('Clear search'),
                icon: const Icon(WicchuIcons.x),
                onPressed: onClear,
              ),
          ],
        ),
      ),
      isDense: true,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .25),
        ),
      ),
    ),
  );
}
