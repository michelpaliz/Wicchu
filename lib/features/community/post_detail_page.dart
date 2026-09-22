import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'comments_sheet.dart';
import 'post_card.dart';
import 'post_share.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.postId,
    required this.repository,
    this.initialPost,
    this.category = 'Post',
    this.icon = '💬',
    this.community = 'Wicchu',
  });

  final String postId;
  final CommunityRepository repository;
  final CommunityPost? initialPost;
  final String category;
  final String icon;
  final String community;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<CommunityPost> _post = widget.repository.getPost(widget.postId);

  Future<void> _reload() async {
    setState(() => _post = widget.repository.getPost(widget.postId));
    try {
      await _post;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Post'))),
    body: FutureBuilder<CommunityPost>(
      future: _post,
      initialData: widget.initialPost,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.trError(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final post = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              PostCard(
                category: widget.category,
                icon: widget.icon,
                community: widget.community,
                author: post.authorName,
                time: formatPostTime(context, post.createdAt),
                text: post.text,
                likes: post.reactionCount,
                comments: post.commentCount,
                media: post.media,
                poll: post.poll,
                onPollVote: (optionId) => widget.repository.voteOnPost(post.id, optionId),
                reacted: post.reactedByMe,
                onReaction: (reacted) => widget.repository.setPostReaction(
                  post.id,
                  reacted: reacted,
                ),
                onComments: () =>
                    showPostComments(context, widget.repository, post),
                saved: post.savedByMe,
                onSaved: (saved) =>
                    widget.repository.setPostSaved(post.id, saved: saved),
                onReport: (reason) =>
                    widget.repository.reportPost(post.id, reason),
                onShare: () => sharePost(
                  widget.repository,
                  post,
                  communityName: widget.community,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    showPostComments(context, widget.repository, post),
                icon: const Icon(Icons.forum_outlined),
                label: Text(context.tr('Open comments')),
              ),
            ],
          ),
        );
      },
    ),
  );
}
