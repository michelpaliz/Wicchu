import 'package:flutter/material.dart';
import '../domain/community_models.dart';
import 'animated_neon_border.dart';
import 'profile_accent_picker.dart';

/// Reuses the shared animation renderer along the toolbar's bottom edge only.
class ProfileTopBarGlow extends StatelessWidget {
  const ProfileTopBarGlow({
    super.key,
    required this.accent,
    this.animation = NeonBorderAnimation.staticGlow,
    this.durationSeconds = 5,
  });
  final String accent;
  final NeonBorderAnimation animation;
  final double durationSeconds;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedNeonBorder(
        color: profileAccentColor(accent),
        enabled: true,
        animation: animation,
        durationSeconds: durationSeconds,
        bottomEdgeOnly: true,
        padding: EdgeInsets.zero,
        strokeWidth: 1.5,
        child: const SizedBox.expand(),
      ),
    ),
  );
}
