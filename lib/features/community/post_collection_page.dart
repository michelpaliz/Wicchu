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
  });

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
    appBar: AppBar(title: Text(context.tr(widget.title))),
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
                onAuthorTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberProfilePage(
                      userId: post.authorId,
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
