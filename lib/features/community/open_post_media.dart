import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../profile/member_profile_page.dart';
import 'comments_sheet.dart';
import 'create_post_page.dart';
import 'post_card.dart';
import 'post_share.dart';

/// Entry point for thumbnails outside a post card. Feed cards use the same
/// viewer with their existing permission-aware actions.
Future<void> openCommunityPostMedia(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post, {
  int initialIndex = 0,
  String communityName = 'Wicchu',
  String category = 'Post',
  String categoryIcon = '💬',
}) async {
  await PostCard(
    repository: repository,
    post: post,
    category: category,
    icon: categoryIcon,
    community: communityName,
    author: post.authorName,
    authorAvatarUrl: post.authorAvatarUrl,
    isAnonymousAuthor: post.isAnonymous,
    time: formatPostTime(context, post.createdAt),
    text: post.text,
    media: post.media,
    edited: post.editedAt != null,
    likes: post.reactionCount,
    comments: post.commentCount,
    reacted: post.reactedByMe,
    saved: post.savedByMe,
    poll: post.poll,
    onPollVote: (optionId) => repository.voteOnPost(post.id, optionId),
    onReaction: (reacted) =>
        repository.setPostReaction(post.id, reacted: reacted),
    onComments: () => showPostComments(context, repository, post),
    onSaved: (saved) => repository.setPostSaved(post.id, saved: saved),
    onShare: () => sharePost(repository, post, communityName: communityName),
    onReport: (reason, category, {hidePost}) => repository.reportPost(
      post.id,
      reason,
      category: category,
      hidePost: hidePost == true,
    ),
    onEdit: post.ownedByMe
        ? () => openEditPost(context, repository, post)
        : null,
    onDelete: post.ownedByMe ? () => repository.deletePost(post.id) : null,
    onAuthorTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemberProfilePage(userId: post.authorId, repository: repository),
      ),
    ),
    onMentionTap: (userId) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemberProfilePage(userId: userId, repository: repository),
      ),
    ),
  ).openMedia(context, initialIndex: initialIndex);
}
