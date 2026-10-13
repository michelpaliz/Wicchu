import '../features/community/post_markdown.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
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
        icon: const Icon(WicchuIcons.gridNine),
      ),
      IconButton(
        tooltip: context.tr('Posts'),
        isSelected: !grid,
        onPressed: () => onChanged(false),
        icon: const Icon(WicchuIcons.rows),
      ),
    ],
  );
}

const profilePostGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  childAspectRatio: 1,
  crossAxisSpacing: 4,
  mainAxisSpacing: 4,
);

/// Shared thumbnail for personal profiles, communities, and public pages.
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
    final photo =
        post.media.where((m) => m.type == 'image').firstOrNull ??
        post.media.where((m) => m.thumbnailUrl?.isNotEmpty == true).firstOrNull;
    final video = post.media.any((m) => m.type == 'video');
    final marker = video
        ? WicchuIcons.playCircle
        : post.media.length > 1
        ? WicchuIcons.images
        : null;
    final fallback = Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final lineHeight = MediaQuery.textScalerOf(context).scale(13) * 1.4;
          return Text(
            postPlainText(post.displayText),
            maxLines: (constraints.maxHeight / lineHeight).floor().clamp(1, 8),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.4,
              color: colors.onSurface,
            ),
          );
        },
      ),
    );
    return Semantics(
      button: true,
      label: '${context.tr('Posts')}: ${post.text}',
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                  decodeWidth: 360,
                  errorBuilder: (_) => fallback,
                )
              else
                fallback,
              if (post.pinned)
                Positioned(
                  top: 5,
                  right: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        WicchuIcons.pushPinFill,
                        size: 14,
                        color: colors.onPrimary,
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
