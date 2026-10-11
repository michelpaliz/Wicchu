import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Shared dimensions for the cover's existing avatar and membership cutouts.
/// Community and public pages share these cutouts. A straight boundary remains
/// available to callers with a cover-only layout.
abstract final class CommunityHeaderGeometry {
  static const overlap = 8.0;
  static const avatarRadius = 32.0;
  static const avatarOutline = 2.0;
  static const cutoutPadding = 5.0;
  static const avatarOuterRadius = avatarRadius + avatarOutline + cutoutPadding;
  static const avatarCorners = BorderRadius.only(
    topLeft: Radius.circular(avatarOuterRadius),
    topRight: Radius.circular(avatarOuterRadius),
    bottomRight: Radius.circular(avatarOuterRadius),
  );
  static const membershipWidth = 48.0;
  static const membershipHeight = 50.0;
  static const membershipRadius = 20.0;
  static const membershipCorners = BorderRadius.vertical(
    top: Radius.circular(membershipRadius),
  );
  static const membershipOuterRadius = membershipRadius + cutoutPadding;
  static const membershipOuterCorners = BorderRadius.vertical(
    top: Radius.circular(membershipOuterRadius),
  );
  static const membershipPadding = EdgeInsets.fromLTRB(
    cutoutPadding,
    cutoutPadding,
    cutoutPadding,
    0,
  );

  /// Only the exposed cover/information boundary, without outer page edges.
  static Path boundary(
    Size size, {
    required bool cutouts,
    required bool membership,
  }) {
    if (!cutouts) {
      return Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height);
    }
    final baseline = size.height - overlap;
    const radius = avatarOuterRadius;
    final center = Offset(radius, size.height - radius);
    final path = Path()
      ..moveTo(0, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi + math.asin((radius - overlap) / radius),
        false,
      );
    if (membership) {
      const width = membershipWidth + cutoutPadding * 2;
      const height = membershipHeight + cutoutPadding;
      const r = membershipOuterRadius;
      final left = size.width - width;
      final top = size.height - height;
      path
        ..lineTo(left, baseline)
        ..lineTo(left, top + r)
        ..arcToPoint(Offset(left + r, top), radius: const Radius.circular(r))
        ..lineTo(size.width - r, top)
        ..arcToPoint(
          Offset(size.width, top + r),
          radius: const Radius.circular(r),
        );
      // The right side touches the page edge; it is not a cover boundary.
    } else {
      path.lineTo(size.width, baseline);
    }
    return path;
  }
}

/// Receives the resolved page accent, so the existing appearance remains the
/// only color source. This overlay never intercepts header actions.
class CommunityHeaderBorder extends StatelessWidget {
  const CommunityHeaderBorder({
    super.key,
    required this.color,
    required this.cutouts,
    required this.membership,
    this.glow = const [],
  });

  final Color color;
  final bool cutouts;
  final bool membership;
  final List<BoxShadow> glow;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: CommunityHeaderBorderPainter(
          color: color,
          cutouts: cutouts,
          membership: membership,
          glow: glow,
        ),
      ),
    ),
  );
}

class CommunityHeaderBorderPainter extends CustomPainter {
  const CommunityHeaderBorderPainter({
    required this.color,
    required this.cutouts,
    required this.membership,
    this.glow = const [],
  });

  final Color color;
  final bool cutouts;
  final bool membership;
  final List<BoxShadow> glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = CommunityHeaderGeometry.boundary(
      size,
      cutouts: cutouts,
      membership: membership,
    );
    for (final shadow in glow) {
      canvas.drawPath(
        path.shift(shadow.offset),
        shadow.toPaint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + shadow.spreadRadius * 2,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(CommunityHeaderBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      cutouts != oldDelegate.cutouts ||
      membership != oldDelegate.membership ||
      !listEquals(glow, oldDelegate.glow);
}
