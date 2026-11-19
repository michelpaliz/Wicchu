import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../theme/wicchu_theme.dart';
import '../../widgets/emoji_aware_text.dart';
import '../../widgets/wicchu_network_image.dart';
import '../community/post_card.dart';
import '../community/post_markdown.dart';

/// Home-only summaries; individual spaces retain their full pinned posts.
class HomePinnedPosts extends StatelessWidget {
  const HomePinnedPosts({
    super.key,
    required this.posts,
    required this.communities,
    required this.onOpen,
  });

  final List<CommunityPost> posts;
  final Map<String, Community> communities;
  final ValueChanged<CommunityPost> onOpen;

  Widget _preview(
    BuildContext context,
    CommunityPost post, {
    double width = 240,
  }) {
    final theme = Theme.of(context);
    final previewText = postPlainText(post.displayText);
    return SizedBox(
      width: width,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('home-pinned-${post.id}'),
          onTap: () => onOpen(post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (post.media.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: WicchuNetworkImage(
                      url: post.media.first.previewUrl,
                      cacheKey: post.media.first.previewCacheKey,
                      fit: BoxFit.cover,
                      decodeWidth: 600,
                      loadingBuilder: (_) => Center(
                        child: Icon(
                          post.media.first.type == 'video'
                              ? WicchuIcons.playFill
                              : WicchuIcons.image,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      errorBuilder: (_) => Center(
                        child: Icon(
                          WicchuIcons.image,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text.rich(
                emojiAwareTextSpan(
                  previewText.isEmpty ? context.tr('Publication') : previewText,
                  style: WicchuPostTypography.title(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  post.isPersonal
                      ? (post.isAnonymous
                            ? context.tr('Anonymous')
                            : post.authorName)
                      : communities[post.sourceCommunityId ?? post.communityId]
                                ?.name ??
                            communities[post.communityId]?.name ??
                            post.authorName,
                  formatPostTime(context, post.createdAt),
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WicchuPostTypography.metadata(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Pinned posts'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 16),
              Semantics(
                label: context.trCount(
                  posts.length,
                  singular: '{count} post',
                  plural: '{count} posts',
                ),
                child: ExcludeSemantics(
                  child: Text(
                    '${posts.length}',
                    style: WicchuPostTypography.metadata(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (posts.length == 1)
          Padding(
            key: const ValueKey('home-pinned-featured'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _preview(context, posts.single),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const compactGap = 12.0;
              const minimumCompactCardWidth = 160.0;
              final twoColumnWidth =
                  (constraints.maxWidth - 32 - compactGap) / 2;
              final showsTwoCompleteCards =
                  twoColumnWidth >= minimumCompactCardWidth &&
                  constraints.maxWidth < 600;
              final cardWidth = showsTwoCompleteCards
                  ? twoColumnWidth
                  : math.min(360.0, math.max(0.0, constraints.maxWidth - 32));
              final gap = showsTwoCompleteCards ? compactGap : 16.0;
              return SingleChildScrollView(
                key: const ValueKey('home-pinned-carousel'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, post) in posts.indexed) ...[
                      if (index > 0) SizedBox(width: gap),
                      _preview(context, post, width: cardWidth),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
