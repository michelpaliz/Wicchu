import 'package:flutter/material.dart';
import '../theme/wicchu_icons.dart';

// Theme-aware vector composition using Wicchu's established icon library.
class WicchuEmptyIllustration extends StatelessWidget {
  const WicchuEmptyIllustration({
    super.key,
    this.centerIcon = WicchuIcons.image,
    this.leftIcon = WicchuIcons.note,
    this.rightIcon = WicchuIcons.note,
    this.accentIcon = WicchuIcons.paperPlaneTilt,
  });
  final IconData centerIcon, leftIcon, rightIcon, accentIcon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget card(IconData icon, double angle, double size) => Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size * 1.15,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.primary.withValues(alpha: .25),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * .65,
            color: colors.primary.withValues(alpha: .65),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 160,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 280,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(80),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  bottom: 14,
                  child: card(leftIcon, -.25, 75),
                ),
                Positioned(
                  right: 35,
                  bottom: 16,
                  child: card(rightIcon, .16, 83),
                ),
                Positioned(
                  left: 87,
                  top: 15,
                  child: card(centerIcon, -.15, 100),
                ),
                Positioned(
                  right: 5,
                  top: 0,
                  child: Icon(accentIcon, size: 44, color: colors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
