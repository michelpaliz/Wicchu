import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'comments_sheet.dart';
import 'post_card.dart';

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
          return Center(child: Text(snapshot.error.toString()));
        }
        final posts = snapshot.data ?? const [];
        if (posts.isEmpty) {
          return Center(child: Text(context.tr('No posts found')));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _posts = widget.loadPosts()),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                category: 'Post',
                icon: '💬',
                community: 'Wicchu',
                author: post.authorName,
                time: formatPostTime(post.createdAt),
                text: post.text,
                likes: post.reactionCount,
                comments: post.commentCount,
                media: post.media,
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
              );
            },
          ),
        );
      },
    ),
  );
}
