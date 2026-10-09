import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../localization/app_language.dart';

/// Shared empty state for a community's selected category.
class CategoryEmptyState extends StatelessWidget {
  const CategoryEmptyState({super.key, required this.category, this.onPublish});

  final String category;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = context.tr(category);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 200,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 170,
                  height: 130,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(70),
                  ),
                ),
                Icon(WicchuIcons.package, size: 92, color: scheme.primary),
                Positioned(
                  right: 35,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      WicchuIcons.tag,
                      size: 26,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('No posts in {category} yet', {'category': name}),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('Be the first to share something in this category.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (onPublish != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPublish,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(WicchuIcons.plus),
              label: Text(
                context.tr('Post in {category}', {'category': name}),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
