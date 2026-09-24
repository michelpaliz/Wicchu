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
      height: 44,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        pressElevation: 0,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        labelStyle: TextStyle(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
