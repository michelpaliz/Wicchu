import 'package:flutter/material.dart';
import 'wicchu_network_image.dart';

import '../domain/community_models.dart';
import '../localization/app_language.dart';

class ProfileViewSwitch extends StatelessWidget {
  const ProfileViewSwitch({
    super.key,
    required this.grid,
    required this.onChanged,
  });
  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      IconButton(
        tooltip: context.tr('Grid'),
        isSelected: grid,
        onPressed: () => onChanged(true),
        icon: const Icon(Icons.grid_on_outlined),
      ),
      IconButton(
        tooltip: context.tr('Posts'),
        isSelected: !grid,
        onPressed: () => onChanged(false),
        icon: const Icon(Icons.view_agenda_outlined),
      ),
    ],
  );
}

/// Used by both personal profiles and public pages; communities retain a feed.
class ProfilePostTile extends StatelessWidget {
  const ProfilePostTile({
    super.key,
    required this.post,
    required this.onTap,
    this.categoryIcon = '💬',
  });
  final CommunityPost post;
  final VoidCallback onTap;
  final String categoryIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = post.media.where((m) => m.type == 'image').firstOrNull;
    final video = post.media.any((m) => m.type == 'video');
    final marker = video
        ? Icons.play_circle_outline
        : post.media.length > 1
        ? Icons.collections_outlined
        : null;
    final fallback = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(categoryIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              post.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: '${context.tr('Posts')}: ${post.text}',
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo != null)
                WicchuNetworkImage(
                  url: photo.previewUrl,
                  cacheKey: photo.previewCacheKey,
                  fit: BoxFit.cover,
                  decodeWidth: 720,
                  errorBuilder: (_) => fallback,
                )
              else
                fallback,
              if (post.reactionCount > 0)
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${post.reactionCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (marker != null)
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(marker, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
