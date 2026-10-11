import 'package:flutter/material.dart';

/// Compact feed navigation, separate from form selection controls.
class FeedCategoryChip extends StatelessWidget {
  const FeedCategoryChip({
    super.key,
    required this.label,
    this.height = 48,
    required this.selected,
    required this.onSelected,
    this.unreadCount = 0,
    this.pulse = false,
  });

  final double height;
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final int unreadCount;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey('$label-$pulse'),
      tween: Tween(begin: pulse && !animationsDisabled ? 1 : 0, end: 0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, glow, _) => SizedBox(
        height: height,
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  padding: unreadCount > 1
                      ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: selected ? scheme.onPrimary : scheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: unreadCount > 1
                      ? Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            color: selected ? scheme.primary : scheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ],
            ],
          ),
          selected: selected,
          showCheckmark: false,
          side: glow > 0
              ? BorderSide(
                  color: scheme.primary.withValues(alpha: .75 * glow),
                  width: 2,
                )
              : selected
              ? BorderSide.none
              : BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.transparent,
          selectedColor: scheme.primary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          pressElevation: 0,
          materialTapTargetSize: height < 48
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          padding: EdgeInsets.symmetric(
            horizontal: 2,
            vertical: height < 48 ? 0 : 2,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          labelStyle: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          onSelected: (_) => onSelected(),
        ),
      ),
    );
  }
}
