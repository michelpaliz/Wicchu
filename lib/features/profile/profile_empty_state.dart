import 'package:flutter/material.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';

/// First-post guidance, shown only on the owner's empty publications tab.
class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({super.key, required this.onCreate, this.onExplore});
  final VoidCallback onCreate;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Column(
        children: [
          const ExcludeSemantics(child: _PublicationIllustration()),
          const SizedBox(height: 20),
          Text(
            context.tr('You haven’t shared anything yet'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Share your ideas, photos, videos or moments with your community. Your first post could inspire others.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('profile-first-post'),
              onPressed: onCreate,
              icon: const Icon(WicchuIcons.plus, size: 20),
              label: Text(
                context.tr('Create your first post'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (onExplore != null)
            TextButton(
              onPressed: onExplore,
              child: Text(context.tr('Explore communities')),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(WicchuIcons.lightbulb, color: colors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Tip'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Share what you love: places, news, events, recommendations and more.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Theme-aware vector composition using Wicchu's established icon library.
class _PublicationIllustration extends StatelessWidget {
  const _PublicationIllustration();
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
                  child: card(WicchuIcons.note, -.25, 75),
                ),
                Positioned(
                  right: 35,
                  bottom: 16,
                  child: card(WicchuIcons.note, .16, 83),
                ),
                Positioned(
                  left: 87,
                  top: 15,
                  child: card(WicchuIcons.image, -.15, 100),
                ),
                Positioned(
                  right: 5,
                  top: 0,
                  child: Icon(
                    WicchuIcons.paperPlaneTilt,
                    size: 44,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
