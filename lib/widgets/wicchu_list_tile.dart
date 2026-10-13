import 'package:flutter/material.dart';

enum WicchuListVariant {
  person,
  community,
  business,
  conversation,
  notification,
  settings,
}

/// Flat list presentation. Content can grow for large text; it is never clipped
/// to a fixed row height. Callers retain navigation and secondary actions.
class WicchuListTile extends StatelessWidget {
  const WicchuListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.variant = WicchuListVariant.person,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
  }) : child = null,
       margin = EdgeInsets.zero;

  const WicchuListTile.custom({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.variant = WicchuListVariant.person,
  }) : title = null,
       subtitle = null,
       leading = null,
       trailing = null,
       onTap = null,
       contentPadding = EdgeInsets.zero;

  final Widget? title, subtitle, leading, trailing, child;
  final VoidCallback? onTap;
  final WicchuListVariant variant;
  final EdgeInsetsGeometry contentPadding, margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final primary = theme.textTheme.titleMedium!.copyWith(
      fontSize: 15,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    );
    final secondary = theme.textTheme.bodySmall!.copyWith(
      fontSize: 12,
      height: 1.35,
      color: colors.onSurfaceVariant,
    );
    final inset = margin.resolve(Directionality.of(context));
    return Padding(
      // Lists own their horizontal inset; rows do not add card-like gaps.
      padding: EdgeInsets.only(left: inset.left, right: inset.right),
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.copyWith(
              titleMedium: primary,
              titleSmall: primary,
              bodyLarge: primary,
              bodyMedium: secondary,
              bodySmall: secondary,
            ),
            listTileTheme: theme.listTileTheme.copyWith(
              titleTextStyle: primary,
              subtitleTextStyle: secondary,
              tileColor: Colors.transparent,
              minTileHeight: 64,
              horizontalTitleGap: 12,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child:
                child ??
                ListTile(
                  contentPadding: contentPadding,
                  leading: leading,
                  title: title,
                  subtitle: subtitle,
                  trailing: trailing,
                  onTap: onTap,
                  titleTextStyle: primary,
                  subtitleTextStyle: secondary,
                ),
          ),
        ),
      ),
    );
  }
}
