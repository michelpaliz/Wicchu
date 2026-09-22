import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import 'comments_sheet.dart';
import 'post_card.dart';

Future<void> openPostDetail(
  BuildContext context, {
  required CommunityRepository repository,
  required CommunityPost post,
  required String category,
  required String icon,
  required String community,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PostDetailPage(
      repository: repository,
      postId: post.id,
      initialPost: post,
      category: category,
      icon: icon,
      community: community,
    ),
  ),
);

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.repository,
    required this.postId,
    required this.category,
    required this.icon,
    required this.community,
    this.initialPost,
  });

  final CommunityRepository repository;
  final String postId;
  final CommunityPost? initialPost;
  final String category;
  final String icon;
  final String community;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late Future<CommunityPost> _post = widget.repository.getPost(widget.postId);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Post')),
    body: FutureBuilder<CommunityPost>(
      future: _post,
      initialData: widget.initialPost,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return Center(
            child: Text(snapshot.error?.toString() ?? 'Post not found'),
          );
        }
        final post = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _post = widget.repository.getPost(widget.postId));
            await _post;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PostCard(
                category: widget.category,
                icon: widget.icon,
                community: widget.community,
                author: post.authorName,
                time: formatPostTime(post.createdAt),
                text: post.text,
                likes: post.reactionCount,
                comments: post.commentCount,
                reacted: post.reactedByMe,
                saved: post.savedByMe,
                media: post.media,
                onReaction: (reacted) => widget.repository.setPostReaction(
                  post.id,
                  reacted: reacted,
                ),
                onComments: () =>
                    showPostComments(context, widget.repository, post),
                onSaved: (saved) =>
                    widget.repository.setPostSaved(post.id, saved: saved),
                onReport: (reason) =>
                    widget.repository.reportPost(post.id, reason),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    showPostComments(context, widget.repository, post),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open comments'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
