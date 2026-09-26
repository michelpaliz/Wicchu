import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/feed_filter_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/comments_sheet.dart';
import '../community/user_avatar.dart';
import '../community/post_share.dart';
import 'edit_profile_links.dart';
import '../community/create_post_page.dart';
import '../community/post_card.dart';
import '../community/post_detail_page.dart';

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({
    super.key,
    required this.userId,
    required this.repository,
  });

  final String userId;
  final CommunityRepository repository;

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  late final Future<WicchuProfile?> _viewer = widget.repository
      .getProfile()
      .then<WicchuProfile?>((profile) => profile)
      .catchError((Object _) => null);
  String _kind = 'all';
  String _sort = 'newest';
  late Future<PublicMemberProfile> _profile = widget.repository
      .getMemberProfile(widget.userId);
  late Future<List<CommunityPost>> _posts = _loadPosts();

  final Map<String, CommunityCategory> _categories = {};
  final Map<String, String> _communityNames = {};

  Future<List<CommunityPost>> _loadPosts() async {
    final posts = await widget.repository.listMemberPosts(
      widget.userId,
      kind: _kind,
      sort: _sort,
    );
    try {
      final communities = await widget.repository.listJoinedCommunities();
      for (final community in communities) {
        _communityNames[community.id] = community.name;
      }
      await Future.wait(
        posts.map((post) => post.communityId).toSet().map((id) async {
          final categories = await widget.repository.listCategories(id);
          for (final category in categories) {
            _categories[category.id] = category;
          }
        }),
      );
    } catch (_) {
      // A public post can remain visible even when its community metadata is private.
    }
    return posts;
  }

  void _reload() => setState(() {
    _profile = widget.repository.getMemberProfile(widget.userId);
    _posts = _loadPosts();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 48,
      title: Text(
        context.tr('Profile'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        _reload();
        await Future.wait([_profile, _posts]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          FutureBuilder<PublicMemberProfile>(
            future: _profile,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(context.trError(snapshot.error!));
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final profile = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          UserAvatar(
                            name: profile.name,
                            imageUrl: profile.avatarUrl,
                            radius: 32,
                          ),
                          if (profile.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (profile.userName.isNotEmpty)
                              Text(
                                '@${profile.userName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            if (profile.isOnline)
                              Text(
                                context.tr('Online now'),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              )
                            else if (profile.lastActiveAt != null)
                              Text(context.tr('Active recently')),
                            Text(
                              '${context.trCount(profile.postCount, singular: '{count} post', plural: '{count} posts')} · '
                              '${context.trCount(profile.communityCount, singular: '{count} community', plural: '{count} communities')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FutureBuilder<WicchuProfile?>(
                        future: _viewer,
                        builder: (context, viewer) =>
                            viewer.data?.id != widget.userId
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: Text(context.tr('Edit')),
                                  onPressed: () async {
                                    await editProfileLinks(
                                      context,
                                      widget.repository,
                                    );
                                    if (mounted) _reload();
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                  ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (profile.socialLinks.whatsapp.isNotEmpty)
                          ActionChip(
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.10),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            label: const Text('WhatsApp'),
                            avatar: const Icon(Icons.chat_outlined, size: 18),
                            onPressed: () => _openSocial(
                              'whatsapp',
                              profile.socialLinks.whatsapp,
                            ),
                          ),
                        if (profile.socialLinks.facebook.isNotEmpty)
                          ActionChip(
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.10),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            label: const Text('Facebook'),
                            avatar: const Icon(Icons.facebook, size: 18),
                            onPressed: () => _openSocial(
                              'facebook',
                              profile.socialLinks.facebook,
                            ),
                          ),
                        if (profile.socialLinks.instagram.isNotEmpty)
                          ActionChip(
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.10),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            label: const Text('Instagram'),
                            avatar: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            onPressed: () => _openSocial(
                              'instagram',
                              profile.socialLinks.instagram,
                            ),
                          ),
                        if (profile.socialLinks.email.isNotEmpty)
                          ActionChip(
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.10),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            label: const Text('Email'),
                            avatar: const Icon(Icons.email_outlined, size: 18),
                            onPressed: () =>
                                _openSocial('email', profile.socialLinks.email),
                          ),
                        ActionChip(
                          label: Text(context.tr('Share profile')),
                          avatar: const Icon(
                            Icons.ios_share_outlined,
                            size: 18,
                          ),
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.10),
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          onPressed: () => _shareProfile(profile),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          FeedFilterBar(
            style: FeedNavigationStyle.underline,
            labels: [
              context.tr('Posts'),
              context.tr('Media'),
              context.tr('Polls'),
            ],
            selectedIndex: const ['all', 'media', 'polls'].indexOf(_kind),
            onSelected: (index) => setState(() {
              _kind = const ['all', 'media', 'polls'][index];
              _posts = _loadPosts();
            }),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: DropdownButton<String>(
              isDense: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              underline: const SizedBox.shrink(),
              iconSize: 18,
              style: Theme.of(context).textTheme.bodySmall,
              value: _sort,
              items: [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text(context.tr('Newest')),
                ),
                DropdownMenuItem(
                  value: 'oldest',
                  child: Text(context.tr('Oldest')),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _sort = value;
                  _posts = _loadPosts();
                });
              },
            ),
          ),
          const SizedBox(height: 4),
          FutureBuilder<List<CommunityPost>>(
            future: _posts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(context.trError(snapshot.error!));
              }
              final posts = snapshot.data ?? const [];
              if (posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(context.tr('No posts found'))),
                );
              }
              return Column(
                children: [
                  for (final post in posts) ...[
                    PostCard(
                      key: ValueKey(post.id),
                      collapseText: true,
                      authorAvatarUrl: post.authorAvatarUrl,
                      onShare: () => sharePost(widget.repository, post),
                      category:
                          _categories[post.categoryId]?.name ?? 'Publication',
                      icon: _categories[post.categoryId]?.icon ?? '💬',
                      community: _communityNames[post.communityId] ?? 'Wicchu',
                      author: post.authorName,
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
                              await openEditPost(
                                context,
                                widget.repository,
                                post,
                              );
                              if (mounted) _reload();
                            }
                          : null,
                      onDelete: post.ownedByMe
                          ? () async {
                              await widget.repository.deletePost(post.id);
                              if (mounted) _reload();
                            }
                          : null,
                      text: post.text,
                      likes: post.reactionCount,
                      comments: post.commentCount,
                      media: post.media,
                      poll: post.poll,
                      reacted: post.reactedByMe,
                      saved: post.savedByMe,
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
                            if (mounted) _reload();
                          }),
                      onReaction: (reacted) => widget.repository
                          .setPostReaction(post.id, reacted: reacted),
                      onPollVote: (optionId) =>
                          widget.repository.voteOnPost(post.id, optionId),
                      onComments: () =>
                          showPostComments(context, widget.repository, post),
                      onSaved: (saved) =>
                          widget.repository.setPostSaved(post.id, saved: saved),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _shareProfile(PublicMemberProfile profile) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: context.tr('Share profile'),
          text:
              '${profile.name} · Wicchu${profile.userName.isEmpty ? '' : '\n@${profile.userName}'}',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _openSocial(String network, String value) async {
    final uri = switch (network) {
      'whatsapp' => Uri.parse('https://wa.me/${value.replaceFirst('+', '')}'),
      'facebook' =>
        value.startsWith('https://')
            ? Uri.parse(value)
            : Uri.parse('https://facebook.com/$value'),
      'instagram' =>
        value.startsWith('https://')
            ? Uri.parse(value)
            : Uri.parse('https://instagram.com/$value'),
      _ => Uri(scheme: 'mailto', path: value),
    };
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Unable to open link'))),
      );
    }
  }
}
