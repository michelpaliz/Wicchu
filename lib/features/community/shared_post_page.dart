import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import 'community_avatar.dart';
import 'comments_sheet.dart';
import 'post_card.dart';
import '../profile/member_profile_page.dart';
import 'post_share.dart';

class SharedPostPage extends StatefulWidget {
  const SharedPostPage({
    super.key,
    required this.postId,
    required this.repository,
  });

  final String postId;
  final CommunityRepository repository;

  @override
  State<SharedPostPage> createState() => _SharedPostPageState();
}

class _SharedPostPageState extends State<SharedPostPage> {
  late final Future<SharedPostPreview> _preview = widget.repository
      .getSharedPost(widget.postId);
  bool _joining = false;
  bool _joined = false;
  CommunityPost? _fullPost;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shared post')),
    body: FutureBuilder<SharedPostPreview>(
      future: _preview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.error?.toString() ?? 'This post is unavailable.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final preview = snapshot.data!;
        final post = _fullPost ?? preview.post;
        final community = Community(
          id: preview.communityId,
          name: preview.communityName,
          description: preview.communityDescription,
          town: const Town(id: '', name: '', countryCode: ''),
          visibility: CommunityVisibility.public,
          createdBy: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          imageUrl: preview.communityImageUrl,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CommunityAvatar(community: community),
                title: Text(preview.communityName),
                subtitle: Text(preview.communityDescription),
                trailing: FilledButton.tonal(
                  onPressed: _joining || _joined
                      ? null
                      : () => _join(preview.communityId),
                  child: _joining
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_joined ? 'Joined' : 'Join'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PostCard(
              category: preview.categoryName,
              icon: preview.categoryIcon,
              community: preview.communityName,
              author: post.authorName,
              authorAvatarUrl: post.authorAvatarUrl,
              onAuthorTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => MemberProfilePage(userId: post.authorId, repository: widget.repository),
              )),
              time: formatPostTime(context, post.createdAt),
              text: post.text,
              media: post.media,
              poll: post.poll,
              likes: post.reactionCount,
              comments: post.commentCount,
              reacted: post.reactedByMe,
              saved: post.savedByMe,
              onReaction: !_joined
                  ? null
                  : (reacted) => widget.repository.setPostReaction(
                      post.id,
                      reacted: reacted,
                    ),
              onComments: !_joined
                  ? null
                  : () => showPostComments(context, widget.repository, post),
              onSaved: !_joined
                  ? null
                  : (saved) =>
                        widget.repository.setPostSaved(post.id, saved: saved),
              onReport: !_joined
                  ? null
                  : (reason) => widget.repository.reportPost(post.id, reason),
              onShare: () => sharePost(
                widget.repository,
                post,
                communityName: preview.communityName,
              ),
            ),
            if (!_joined) ...[
              const SizedBox(height: 12),
              const Text(
                'Join this community to like, comment, save, and report posts.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    ),
  );

  Future<void> _join(String communityId) async {
    setState(() => _joining = true);
    try {
      await widget.repository.joinCommunity(communityId);
      final fullPost = await widget.repository.getPost(widget.postId);
      if (mounted) {
        setState(() {
          _joined = true;
          _fullPost = fullPost;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Community joined. You can now interact with the post.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }
}
