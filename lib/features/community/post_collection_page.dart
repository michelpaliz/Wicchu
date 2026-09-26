import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'comments_sheet.dart';
import 'create_post_page.dart';
import 'post_card.dart';
import 'post_detail_page.dart';
import '../profile/member_profile_page.dart';
import 'post_share.dart';

class PostCollectionPage extends StatefulWidget {
  const PostCollectionPage({
    super.key,
    required this.title,
    required this.repository,
    required this.loadPosts,
    this.onBrowsePosts,
  });

  final VoidCallback? onBrowsePosts;
  final String title;
  final CommunityRepository repository;
  final Future<List<CommunityPost>> Function() loadPosts;

  @override
  State<PostCollectionPage> createState() => _PostCollectionPageState();
}

class _PostCollectionPageState extends State<PostCollectionPage> {
  late Future<List<CommunityPost>> _posts = widget.loadPosts();

  Future<void> _refresh() async {
    setState(() {
      _posts = widget.loadPosts();
    });
    try {
      await _posts;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(widget.title),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: FutureBuilder<List<CommunityPost>>(
      future: _posts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final posts = snapshot.data ?? const [];
        if (posts.isEmpty) {
          if (widget.title == 'Saved posts') {
            return _SavedPostsEmptyState(onBrowsePosts: widget.onBrowsePosts);
          }
          return Center(child: Text(context.tr('No posts found')));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                collapseText: true,
                onTap: () =>
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailPage(
                          postId: post.id,
                          repository: widget.repository,
                          initialPost: post,
                        ),
                      ),
                    ).then((_) {
                      if (mounted) setState(() => _posts = widget.loadPosts());
                    }),
                category: 'Post',
                icon: '💬',
                community: 'Wicchu',
                author: post.authorName,
                authorAvatarUrl: post.authorAvatarUrl,
                isAnonymousAuthor: post.isAnonymous,
                onAuthorTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberProfilePage(
                      userId: post.authorId,
                      repository: widget.repository,
                    ),
                  ),
                ),
                onMentionTap: (userId) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberProfilePage(
                      userId: userId,
                      repository: widget.repository,
                    ),
                  ),
                ),
                time: formatPostTime(context, post.createdAt),
                edited: post.editedAt != null,
                onEdit: post.ownedByMe
                    ? () async {
                        await openEditPost(context, widget.repository, post);
                        if (mounted) await _refresh();
                      }
                    : null,
                onDelete: post.ownedByMe
                    ? () async {
                        await widget.repository.deletePost(post.id);
                        if (mounted) await _refresh();
                      }
                    : null,
                text: post.text,
                likes: post.reactionCount,
                comments: post.commentCount,
                media: post.media,
                poll: post.poll,
                onPollVote: (optionId) =>
                    widget.repository.voteOnPost(post.id, optionId),
                promotion: post.promotion,
                onPromotionImpression: post.promotion == null
                    ? null
                    : () => widget.repository.recordPromotionImpression(
                        post.promotion!.id,
                      ),
                onPromotionClick: post.promotion == null
                    ? null
                    : () => widget.repository.recordPromotionClick(
                        post.promotion!.id,
                      ),
                reacted: post.reactedByMe,
                saved: post.savedByMe,
                onReaction: (reacted) => widget.repository.setPostReaction(
                  post.id,
                  reacted: reacted,
                ),
                onComments: () =>
                    showPostComments(context, widget.repository, post),
                onSaved: (saved) async {
                  await widget.repository.setPostSaved(post.id, saved: saved);
                  if (!saved && widget.title == 'Saved posts' && mounted) {
                    setState(() => _posts = widget.loadPosts());
                  }
                },
                onReport: (reason) =>
                    widget.repository.reportPost(post.id, reason),
                onShare: () => sharePost(widget.repository, post),
              );
            },
          ),
        );
      },
    ),
  );
}

class _SavedPostsEmptyState extends StatelessWidget {
  const _SavedPostsEmptyState({this.onBrowsePosts});
  final VoidCallback? onBrowsePosts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 220,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 175,
                            height: 175,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .07),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Transform.rotate(
                            angle: -.07,
                            child: Container(
                              width: 134,
                              height: 152,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: .08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: .07,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: colors.primary
                                            .withValues(alpha: .25),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              height: 5,
                                              width: 58,
                                              color: colors.primary.withValues(
                                                alpha: .2,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Container(
                                              height: 4,
                                              width: 40,
                                              color: colors.primary.withValues(
                                                alpha: .12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: .08,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.landscape_rounded,
                                        size: 65,
                                        color: colors.primary.withValues(
                                          alpha: .23,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        size: 16,
                                        color: colors.primary.withValues(
                                          alpha: .3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 50,
                                        height: 5,
                                        color: colors.primary.withValues(
                                          alpha: .16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 7,
                            bottom: 0,
                            child: Icon(
                              Icons.bookmark_rounded,
                              size: 100,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.tr('You haven’t saved any posts yet'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      context.tr('Save posts you want to revisit later.'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onBrowsePosts != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onBrowsePosts,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.explore),
                      label: Text(context.tr('Explore posts')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
