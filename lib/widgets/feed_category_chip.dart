import 'package:flutter/material.dart';

/// Compact feed navigation, separate from form selection controls.
class FeedCategoryChip extends StatelessWidget {
  const FeedCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        side: selected
            ? BorderSide.none
            : BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        pressElevation: 0,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        labelStyle: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
