import '../community/post_collection_page.dart';
import '../../widgets/profile_post_grid.dart';
import '../../widgets/profile_link_button.dart';
import '../../widgets/block_visibility_listener.dart';
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
import '../community/create_post_page.dart';
import '../community/post_card.dart';

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({
    super.key,
    required this.userId,
    required this.repository,
    this.header,
    this.onAccountMenu,
    this.embedded = false,
  });

  final Widget? header;
  final VoidCallback? onAccountMenu;
  final bool embedded;
  final String userId;
  final CommunityRepository repository;

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage>
    with BlockVisibilityListener<MemberProfilePage> {
  @override
  CommunityRepository get visibilityRepository => widget.repository;
  @override
  void reloadBlockVisibility() {
    _reload();
  }

  bool _blocking = false;
  late final Future<WicchuProfile?> _viewer = widget.repository
      .getProfile()
      .then<WicchuProfile?>((profile) => profile)
      .catchError((Object _) => null);
  String _kind = 'all';
  String _sort = 'newest';
  late Future<PublicMemberProfile> _profile = widget.repository
      .getMemberProfile(widget.userId);
  bool _grid = true;
  late Future<List<CommunityPost>> _posts = _loadPosts();

  final Map<String, CommunityCategory> _categories = {};
  final Map<String, String> _communityNames = {};

  Future<List<CommunityPost>> _loadPosts() async {
    final posts = _kind == 'saved'
        ? (await _viewer)?.id == widget.userId
              ? (await widget.repository.listSavedPosts()).toList()
              : <CommunityPost>[]
        : await widget.repository.listMemberPosts(
            widget.userId,
            kind: _kind,
            sort: _sort,
          );
    if (_kind == 'saved') {
      posts.sort(
        (a, b) => _sort == 'oldest'
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt),
      );
    }
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
      automaticallyImplyLeading: !widget.embedded,
      title:
          widget.header ??
          Text(
            context.tr('Profile'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
      actions: [
        if (widget.onAccountMenu != null)
          IconButton(
            tooltip: context.tr('Account menu'),
            onPressed: widget.onAccountMenu,
            icon: const Icon(Icons.settings_outlined),
          ),
        FutureBuilder<WicchuProfile?>(
          future: _viewer,
          builder: (context, viewer) => viewer.data?.id == widget.userId
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: context.tr('Block user'),
                  onPressed: _blocking ? null : _blockUser,
                  icon: _blocking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.block_outlined),
                ),
        ),
      ],
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
              return _profileHeader(profile);
            },
          ),
          const SizedBox(height: 8),
          FutureBuilder<WicchuProfile?>(
            future: _viewer,
            builder: (context, viewer) {
              final kinds = [
                'all',
                'media',
                'polls',
                if (viewer.data?.id == widget.userId) 'saved',
              ];
              return FeedFilterBar(
                style: FeedNavigationStyle.underline,
                labels: [
                  context.tr('Posts'),
                  context.tr('Media'),
                  context.tr('Polls'),
                  if (viewer.data?.id == widget.userId) context.tr('Saved'),
                ],
                selectedIndex: kinds.indexOf(_kind),
                onSelected: (index) => setState(() {
                  _kind = kinds[index];
                  _posts = _loadPosts();
                }),
              );
            },
          ),
          Row(
            children: [
              ProfileViewSwitch(
                grid: _grid,
                onChanged: (value) => setState(() => _grid = value),
              ),
              const Spacer(),
              DropdownButton<String>(
                isDense: true,
                underline: const SizedBox.shrink(),
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
            ],
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
              if (_grid) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return ProfilePostTile(
                      post: post,
                      categoryIcon: _categories[post.categoryId]?.icon ?? '💬',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostCollectionPage(
                              profilePresentation: true,
                              title: 'Posts',
                              repository: widget.repository,
                              initialPostId: post.id,
                              initialPosts: posts,
                              loadPosts: _loadPosts,
                              categories: _categories,
                              communityNames: _communityNames,
                            ),
                          ),
                        );
                        if (mounted) _reload();
                      },
                    );
                  },
                );
              }
              return Column(
                children: [
                  for (final post in posts) ...[
                    PostCard(
                      key: ValueKey(post.id),
                      collapseText: true,
                      mediaFirst: true,
                      compact: true,
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
                              builder: (_) => PostCollectionPage(
                                title: 'Posts',
                                profilePresentation: true,
                                initialPostId: post.id,
                                initialPosts: posts,
                                repository: widget.repository,
                                loadPosts: _loadPosts,
                                categories: _categories,
                                communityNames: _communityNames,
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

  Widget _profileHeader(PublicMemberProfile profile) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget stat(int count, String label) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$count ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          TextSpan(text: context.tr(label)),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
    return FutureBuilder<WicchuProfile?>(
      future: _viewer,
      builder: (context, viewer) {
        final own = viewer.data?.id == widget.userId;
        final location =
            profile.location ?? (own ? viewer.data?.location : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: profile.socialLinks.isEmpty
                  ? null
                  : () => _openSocialLinks(profile),
              borderRadius: BorderRadius.circular(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    image: true,
                    label: profile.name,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.primary.withValues(alpha: .16),
                            ),
                          ),
                          child: UserAvatar(
                            name: profile.name,
                            imageUrl: profile.avatarUrl,
                            radius: 34,
                          ),
                        ),
                        if (profile.isOnline)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (profile.userName.isNotEmpty)
                          Text(
                            '@${profile.userName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        if (profile.isOnline ||
                            profile.lastActiveAt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            context.tr(
                              profile.isOnline
                                  ? 'Online now'
                                  : 'Active recently',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: profile.isOnline
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (profile.bio?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(profile.bio!, style: theme.textTheme.bodyMedium),
              ),
            if (location?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location!, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    stat(profile.postCount, 'Posts'),
                    stat(profile.communityCount, 'Communities'),
                    if (profile.followerCount != null)
                      stat(profile.followerCount!, 'Followers'),
                    if (profile.followingCount != null)
                      stat(profile.followingCount!, 'Following'),
                  ],
                ),
              ),
            ),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  _profileAction(
                    icon: Icons.ios_share_outlined,
                    label: context.tr('Share'),
                    tooltip: context.tr('Share profile'),
                    onPressed: () => _shareProfile(profile),
                  ),
                  if (own)
                    _profileAction(
                      icon: Icons.person_add_outlined,
                      label: context.tr('Find friends'),
                      tooltip: context.tr('Find friends'),
                      onPressed: _findPeople,
                    ),
                  if (!profile.socialLinks.isEmpty)
                    IconButton(
                      tooltip: context.tr('Social links'),
                      onPressed: () => _openSocialLinks(profile),
                      style: IconButton.styleFrom(
                        foregroundColor: colors.primary,
                        backgroundColor: colors.primary.withValues(alpha: .08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.link, size: 20),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSocialLinks(PublicMemberProfile profile) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(context.tr('Social links'))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in {
                      'whatsapp': profile.socialLinks.whatsapp,
                      'facebook': profile.socialLinks.facebook,
                      'instagram': profile.socialLinks.instagram,
                      'email': profile.socialLinks.email,
                    }.entries)
                      if (entry.value.isNotEmpty)
                        ProfileLinkButton(
                          network: entry.key,
                          onTap: () => _openSocial(entry.key, entry.value),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileAction({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: .08),
          foregroundColor: theme.colorScheme.primary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  Future<void> _findPeople() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FindPeoplePage(
          repository: widget.repository,
          userId: widget.userId,
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Block this user?')),
        content: Text(
          context.tr(
            'You will no longer see each other’s posts, comments, profiles, mentions, or notifications.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Block')),
          ),
        ],
      ),
    );
    if (approved != true) return;
    setState(() => _blocking = true);
    try {
      await widget.repository.blockUser(widget.userId);
      notifyBlockVisibilityChanged(widget.repository);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

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

class _FindPeoplePage extends StatefulWidget {
  const _FindPeoplePage({required this.repository, required this.userId});
  final CommunityRepository repository;
  final String userId;

  @override
  State<_FindPeoplePage> createState() => _FindPeoplePageState();
}

class _FindPeoplePageState extends State<_FindPeoplePage>
    with BlockVisibilityListener<_FindPeoplePage> {
  String _query = '';
  late Future<List<CommunityMember>> _people = _load();
  @override
  CommunityRepository get visibilityRepository => widget.repository;
  @override
  void reloadBlockVisibility() => setState(() {
    _people = _load();
  });

  Future<List<CommunityMember>> _load() async {
    final spaces = await widget.repository.listJoinedCommunities();
    final lists = await Future.wait(
      spaces
          .where((c) => !c.isPublicProfile)
          .map((c) => widget.repository.listMembers(c.id)),
    );
    return {
      for (final member in lists.expand((list) => list))
        if (!member.isAnonymous &&
            member.userId.isNotEmpty &&
            member.userId != widget.userId)
          member.userId: member,
    }.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Find friends'))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) =>
                setState(() => _query = value.toLowerCase().trim()),
            decoration: InputDecoration(
              hintText: context.tr('Search people'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CommunityMember>>(
            future: _people,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: reloadBlockVisibility,
                    child: Text(context.tr('Retry')),
                  ),
                );
              }
              final people = (snapshot.data ?? [])
                  .where((p) => p.name.toLowerCase().contains(_query))
                  .toList();
              if (people.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr('Find people from your communities here.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];
                  return ListTile(
                    leading: UserAvatar(
                      name: person.name,
                      imageUrl: person.avatarUrl,
                      radius: 22,
                    ),
                    title: Text(person.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberProfilePage(
                          userId: person.userId,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
