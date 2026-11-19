import 'package:flutter/material.dart';

import '../theme/wicchu_icons.dart';

/// Shared empty state for publication feeds.
class PostEmptyState extends StatelessWidget {
  const PostEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: .08),
                  ),
                ),
                Transform.rotate(
                  angle: -.12,
                  child: Container(
                    width: 60,
                    height: 70,
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Container(
                  width: 62,
                  height: 68,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    WicchuIcons.image,
                    size: 50,
                    color: scheme.primary.withValues(alpha: .42),
                  ),
                ),
                if (onAction != null)
                  Positioned(
                    right: 0,
                    bottom: 4,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: scheme.primary,
                      child: Icon(
                        WicchuIcons.plus,
                        color: scheme.onPrimary,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('empty-posts-create-action'),
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              icon: const Icon(WicchuIcons.notePencil, size: 20),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
