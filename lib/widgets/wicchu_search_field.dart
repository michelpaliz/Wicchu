import 'package:flutter/material.dart';
import '../localization/app_language.dart';
import '../theme/wicchu_icons.dart';
import 'wicchu_logo.dart';

class WicchuSearchField extends StatelessWidget {
  const WicchuSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.showSearchIcon = true,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showSearchIcon;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: context.tr('Search Wicchu…'),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Container(
          padding: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: .3),
              ),
            ),
          ),
          child: const WicchuLogo(size: 26),
        ),
      ),
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
            if (showSearchIcon)
              const Padding(
                padding: EdgeInsets.only(left: 8, right: 14),
                child: Icon(WicchuIcons.magnifyingGlass, size: 22),
              ),
          ],
        ),
      ),
      isDense: true,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
