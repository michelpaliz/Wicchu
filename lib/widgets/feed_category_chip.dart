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
                Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Container(
                    key: const ValueKey('category-unread-badge'),
                    width: unreadCount == 1 ? 6 : null,
                    height: unreadCount == 1 ? 6 : null,
                    constraints: unreadCount > 1
                        ? const BoxConstraints(minWidth: 18, minHeight: 18)
                        : null,
                    padding: unreadCount > 1
                        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: selected ? scheme.onPrimary : scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: unreadCount > 1
                        ? Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected
                                  ? scheme.primary
                                  : scheme.onPrimary,
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
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
              : BorderSide.none,
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
