import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keeps the shared mobile navigation and its routes readable on wide windows.
class WicchuViewport extends StatelessWidget {
  const WicchuViewport({super.key, required this.child});

  final Widget child;
  static const maxWidth = 600.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final width = math.min(constraints.maxWidth, maxWidth);
      final margin = (constraints.maxWidth - width) / 2;
      EdgeInsets localInsets(EdgeInsets value) => value.copyWith(
        left: math.max(0, value.left - margin),
        right: math.max(0, value.right - margin),
      );
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: MediaQuery(
              data: media.copyWith(
                size: Size(width, constraints.maxHeight),
                padding: localInsets(media.padding),
                viewPadding: localInsets(media.viewPadding),
                viewInsets: localInsets(media.viewInsets),
              ),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
