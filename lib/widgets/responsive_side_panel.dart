import 'package:flutter/material.dart';

const double webDesktopBreakpoint = 1000;

Future<T?> openResponsiveSidePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 720,
}) {
  if (MediaQuery.sizeOf(context).width < webDesktopBreakpoint) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: builder));
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).closeButtonTooltip,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, _, _) {
      final availableWidth = MediaQuery.sizeOf(dialogContext).width - 280;
      final panelWidth = width < availableWidth ? width : availableWidth;
      return SafeArea(
        left: false,
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: Material(
              clipBehavior: Clip.antiAlias,
              elevation: 18,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
              child: builder(dialogContext),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
