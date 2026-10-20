import 'package:flutter/material.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/wicchu_empty_illustration.dart';

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
          const ExcludeSemantics(child: WicchuEmptyIllustration()),
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
        ],
      ),
    );
  }
}
