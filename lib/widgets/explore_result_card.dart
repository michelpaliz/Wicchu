import 'package:flutter/material.dart';

/// Shared surface for Explore results, leaving content and actions to each tab.
class ExploreResultCard extends StatelessWidget {
  const ExploreResultCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: Material(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 1.5,
        shadowColor: colors.shadow.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
