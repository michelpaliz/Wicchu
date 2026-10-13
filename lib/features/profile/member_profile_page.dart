import 'profile_communities_page.dart';
import 'profile_empty_state.dart';
import '../../widgets/explore_result_card.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
import 'dart:async';

import '../community/open_post_media.dart';
import '../community/post_collection_page.dart';
import '../../widgets/profile_post_grid.dart';
import '../../widgets/profile_link_button.dart';
import '../../widgets/block_visibility_listener.dart';
import '../../widgets/profile_accent_picker.dart';
import '../../widgets/animated_neon_border.dart';
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
import '../community/report_dialog.dart';
import '../chat/direct_chat_pages.dart';

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({
    super.key,
    required this.userId,
    required this.repository,
    this.header,
    this.onAccountMenu,
    this.embedded = false,
    this.postRequest,
    this.onExploreCommunities,
  });

  final VoidCallback? onExploreCommunities;
  final Listenable? postRequest;
  final Widget? header;
  final FutureOr<void> Function()? onAccountMenu;
  final bool embedded;
  final String userId;
  final CommunityRepository repository;

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _UserFollowListPage extends StatefulWidget {
  const _UserFollowListPage({
    required this.repository,
    required this.userId,
    required this.followers,
  });

  final CommunityRepository repository;
  final String userId;
  final bool followers;

  @override
  State<_UserFollowListPage> createState() => _UserFollowListPageState();
}

class _UserFollowListPageState extends State<_UserFollowListPage> {
  final _users = <UserFollowProfile>[];
  String? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = widget.followers
          ? await widget.repository.listFollowers(
              widget.userId,
              cursor: refresh ? null : _cursor,
            )
          : await widget.repository.listFollowingUsers(
              widget.userId,
              cursor: refresh ? null : _cursor,
            );
      if (!mounted) return;
      setState(() {
        if (refresh) _users.clear();
        _users.addAll(
          page.users.where((item) => !_users.any((old) => old.id == item.id)),
        );
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr(widget.followers ? 'Followers' : 'Following')),
    ),
    body: SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_users.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  WicchuIcons.usersThree,
                                  size: 28,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error != null
                                    ? context.trError(_error!)
                                    : context.tr(
                                        widget.followers
                                            ? 'No followers yet'
                                            : 'Not following anyone yet',
                                      ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (_error == null)
                                Text(
                                  context.tr(
                                    widget.followers
                                        ? 'Followers will appear here.'
                                        : 'Follow people from their profiles to see them here.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              if (_error != null)
                                FilledButton(
                                  onPressed: () => _load(),
                                  child: Text(context.tr('Retry')),
                                ),
                            ],
                          ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ExploreResultCard(
                      key: ValueKey(user.id),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: UserAvatar(
                          name: user.name,
                          imageUrl: user.avatarUrl,
                          userId: user.id,
                          radius: 24,
                        ),
                        title: Text(
                          user.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: user.userName.isEmpty
                            ? null
                            : Text(
                                '@${user.userName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: const Icon(WicchuIcons.caretRight, size: 18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberProfilePage(
                              userId: user.id,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_hasMore || _loading || _error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Column(
                              children: [
                                if (_error != null)
                                  Text(
                                    context.trError(_error!),
                                    textAlign: TextAlign.center,
                                  ),
                                TextButton(
                                  onPressed: () => _load(refresh: !_hasMore),
                                  child: Text(
                                    context.tr(
                                      _error != null ? 'Retry' : 'Load more',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _FollowRequestsPage extends StatefulWidget {
  const _FollowRequestsPage({required this.repository});
  final CommunityRepository repository;

  @override
  State<_FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends State<_FollowRequestsPage> {
  final _users = <UserFollowProfile>[];
  final _saving = <String>{};
  String? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.listFollowRequests(
        cursor: refresh ? null : _cursor,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _users.clear();
        _users.addAll(
          page.users.where((item) => !_users.any((old) => old.id == item.id)),
        );
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(UserFollowProfile user, bool accept) async {
    if (_saving.contains(user.id)) return;
    setState(() => _saving.add(user.id));
    try {
      await widget.repository.respondToFollowRequest(user.id, accept: accept);
      if (mounted) {
        setState(() => _users.removeWhere((item) => item.id == user.id));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Follow requests'))),
    body: RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_users.isEmpty && _loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  _error == null
                      ? context.tr('No pending follow requests')
                      : context.trError(_error!),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (final user in _users)
              Card(
                child: ListTile(
                  leading: UserAvatar(
                    name: user.name,
                    imageUrl: user.avatarUrl,
                    userId: user.id,
                    radius: 22,
                  ),
                  title: Text(user.name),
                  subtitle: user.userName.isEmpty
                      ? null
                      : Text('@${user.userName}'),
                  trailing: _saving.contains(user.id)
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: context.tr('Reject'),
                              onPressed: () => _respond(user, false),
                              icon: const Icon(WicchuIcons.x),
                            ),
                            IconButton.filled(
                              tooltip: context.tr('Accept'),
                              onPressed: () => _respond(user, true),
                              icon: const Icon(WicchuIcons.check),
                            ),
                          ],
                        ),
                ),
              ),
          if (_error != null || _hasMore)
            TextButton(
              onPressed: _loading ? null : () => _load(refresh: _error != null),
              child: Text(context.tr(_error != null ? 'Retry' : 'Load more')),
            ),
        ],
      ),
    ),
  );
}

class _MemberProfilePageState extends State<MemberProfilePage>
    with BlockVisibilityListener<MemberProfilePage> {
  @override
  CommunityRepository get visibilityRepository => widget.repository;
  @override
  void reloadBlockVisibility() {
    _reload();
  }

  bool _composing = false;

  @override
  void initState() {
    super.initState();
    widget.postRequest?.addListener(_createPersonalPost);
  }

  @override
  void didUpdateWidget(covariant MemberProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postRequest != widget.postRequest) {
      oldWidget.postRequest?.removeListener(_createPersonalPost);
      widget.postRequest?.addListener(_createPersonalPost);
    }
  }

  @override
  void dispose() {
    widget.postRequest?.removeListener(_createPersonalPost);
    super.dispose();
  }

  bool _blocking = false;
  bool _reporting = false;
  bool _followBusy = false;
  bool _notificationBusy = false;
  UserFollowStatus? _followStatus;
  int? _followerCount;
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
      final communityIds = posts
          .map((post) => post.communityId)
          .where((id) => id.isNotEmpty)
          .toSet();
      await Future.wait(
        communityIds.map((id) async {
          if (!_communityNames.containsKey(id)) {
            final community = await widget.repository.getCommunity(id);
            _communityNames[id] = community.name;
          }
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
    _followStatus = null;
    _followerCount = null;
    _profile = widget.repository.getMemberProfile(widget.userId);
    _posts = _loadPosts();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 48,
      centerTitle: false,
      titleSpacing: 8,
      automaticallyImplyLeading: !widget.embedded,
      title:
          widget.header ??
          FutureBuilder<PublicMemberProfile>(
            future: _profile,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return Text(
                profile == null
                    ? ''
                    : profile.userName.isNotEmpty
                    ? '@${profile.userName}'
                    : profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
      actions: [
        FutureBuilder<PublicMemberProfile>(
          future: _profile,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            if (profile == null) return const SizedBox.shrink();
            return FutureBuilder<WicchuProfile?>(
              future: _viewer,
              builder: (context, viewer) {
                final own = viewer.data?.id == widget.userId;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (viewer.hasData && !own)
                      IconButton(
                        tooltip: context.tr('Message'),
                        onPressed: _openChat,
                        icon: const Icon(WicchuIcons.chatCircle, size: 22),
                      ),
                    if (!profile.socialLinks.isEmpty)
                      IconButton(
                        tooltip: context.tr('Social links'),
                        onPressed: () => _openSocialLinks(profile),
                        icon: const Icon(WicchuIcons.linkSimple, size: 22),
                      ),
                    IconButton(
                      tooltip: context.tr('Share profile'),
                      onPressed: () => _shareProfile(profile),
                      icon: const Icon(WicchuIcons.export, size: 22),
                    ),
                    if (own)
                      IconButton(
                        tooltip: context.tr('Find people'),
                        onPressed: _findPeople,
                        icon: const Icon(WicchuIcons.userPlus, size: 22),
                      ),
                    if (own && profile.followRequestCount > 0)
                      Badge.count(
                        count: profile.followRequestCount,
                        child: IconButton(
                          tooltip: context.tr('Follow requests'),
                          onPressed: _openFollowRequests,
                          icon: const Icon(WicchuIcons.users, size: 22),
                        ),
                      ),
                    if (viewer.hasData && !own)
                      PopupMenuButton<String>(
                        tooltip: context.tr('More options'),
                        enabled: !_blocking && !_reporting,
                        icon: const Icon(WicchuIcons.dotsThree, size: 22),
                        onSelected: (value) {
                          if (value == 'block') {
                            _blockUser();
                          } else {
                            _reportMember();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                const Icon(WicchuIcons.prohibit, size: 20),
                                const SizedBox(width: 12),
                                Text(context.tr('Block user')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                const Icon(WicchuIcons.flag, size: 20),
                                const SizedBox(width: 12),
                                Text(context.tr('Report profile')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(width: 4),
                  ],
                );
              },
            );
          },
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
          FeedFilterBar(
            compact: true,
            style: FeedNavigationStyle.underline,
            labels: [context.tr('Posts'), context.tr('Media')],
            selectedIndex: _kind == 'media' ? 1 : 0,
            onSelected: (index) => setState(() {
              _kind = index == 0 ? 'all' : 'media';
              _posts = _loadPosts();
            }),
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
                return FutureBuilder<WicchuProfile?>(
                  future: _viewer,
                  builder: (context, viewer) {
                    if (_kind == 'all' && viewer.data?.id == widget.userId) {
                      return ProfileEmptyState(
                        onCreate: _createPersonalPost,
                        onExplore: widget.onExploreCommunities,
                      );
                    }
                    return FutureBuilder<PublicMemberProfile>(
                      future: _profile,
                      builder: (context, profileSnapshot) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (profileSnapshot.data?.isPrivate == true &&
                                  profileSnapshot.data?.canViewPersonalPosts ==
                                      false) ...[
                                const Icon(WicchuIcons.lockKey, size: 32),
                                const SizedBox(height: 10),
                                Text(
                                  context.tr('This profile is private'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.tr(
                                    'Follow this person to view their personal posts.',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ] else
                                Text(context.tr('No posts found')),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                        if (post.media.isNotEmpty) {
                          await openCommunityPostMedia(
                            context,
                            widget.repository,
                            post,
                            initialIndex: post.media
                                .indexWhere((m) => m.type == 'image')
                                .clamp(0, post.media.length - 1),
                            communityName:
                                _communityNames[post.communityId] ?? 'Wicchu',
                            category:
                                _categories[post.categoryId]?.name ?? 'Post',
                            categoryIcon:
                                _categories[post.categoryId]?.icon ?? '💬',
                          );
                          if (mounted) {
                            setState(() {
                              _posts = _loadPosts();
                            });
                          }
                          return;
                        }
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
                      repository: widget.repository,
                      post: post,
                      key: ValueKey(post.id),
                      collapseText: true,
                      mediaFirst: true,
                      compact: true,
                      authorAvatarUrl: post.authorAvatarUrl,
                      onShare: () =>
                          sharePost(context, widget.repository, post),
                      category: post.isPersonal
                          ? 'Personal publication'
                          : _categories[post.categoryId]?.name ?? 'Publication',
                      icon: _categories[post.categoryId]?.icon ?? '💬',
                      community: post.isPersonal
                          ? context.tr('Personal profile')
                          : _communityNames[post.communityId] ?? 'Wicchu',
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
                      text: post.displayText,
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
                      onReaction: post.canInteract
                          ? (reacted) => widget.repository.setPostReaction(
                              post.id,
                              reacted: reacted,
                            )
                          : null,
                      onPollVote: post.canInteract
                          ? (optionId) =>
                                widget.repository.voteOnPost(post.id, optionId)
                          : null,
                      onComments: () =>
                          showPostComments(context, widget.repository, post),
                      onSaved: post.canInteract
                          ? (saved) => widget.repository.setPostSaved(
                              post.id,
                              saved: saved,
                            )
                          : null,
                      onReport: post.ownedByMe
                          ? null
                          : (reason, category, {hidePost}) =>
                                widget.repository.reportPost(
                                  post.id,
                                  reason,
                                  category: category,
                                  hidePost: hidePost == true,
                                ),
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
    final accent = profileAccentColor(profile.accentColor);
    Widget stat(int count, String label) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$count ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          TextSpan(text: context.tr(label)),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 11,
        color: colors.onSurfaceVariant,
      ),
    );
    return FutureBuilder<WicchuProfile?>(
      future: _viewer,
      builder: (context, viewer) {
        final own = viewer.data?.id == widget.userId;
        _followStatus ??= profile.followStatus;
        _followerCount ??= profile.followerCount ?? 0;
        final location =
            profile.location ?? (own ? viewer.data?.location : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: own && widget.onAccountMenu != null
                  ? context.tr('Account menu')
                  : profile.name,
              child: InkWell(
                onTap: own && widget.onAccountMenu != null
                    ? () async {
                        await widget.onAccountMenu!();
                        if (mounted) _reload();
                      }
                    : profile.socialLinks.isEmpty
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
                          AnimatedNeonBorder(
                            color: accent,
                            enabled: profile.neonBordersEnabled,
                            animation: profile.neonBorderAnimation,
                            durationSeconds:
                                profile.neonAnimationDurationSeconds,
                            child: UserAvatar(
                              name: profile.name,
                              imageUrl: profile.avatarUrl,
                              radius: 30,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 16,
                                runSpacing: 0,
                                children:
                                    [
                                          if (own)
                                            Semantics(
                                              button: true,
                                              child: InkWell(
                                                key: const ValueKey(
                                                  'profile-communities',
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () async {
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ProfileCommunitiesPage(
                                                            repository: widget
                                                                .repository,
                                                          ),
                                                    ),
                                                  );
                                                  if (mounted) _reload();
                                                },
                                                child: ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                        minHeight: 24,
                                                      ),
                                                  child: Align(
                                                    widthFactor: 1,
                                                    heightFactor: 1,
                                                    child: stat(
                                                      profile.communityCount,
                                                      'Communities',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            stat(
                                              profile.communityCount,
                                              'Communities',
                                            ),
                                          Semantics(
                                            button: true,
                                            child: InkWell(
                                              key: const ValueKey(
                                                'profile-followers-count',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onTap: () => _openFollowList(
                                                followers: true,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: stat(
                                                  _followerCount!,
                                                  'Followers',
                                                ),
                                              ),
                                            ),
                                          ),
                                          Semantics(
                                            button: true,
                                            child: InkWell(
                                              key: const ValueKey(
                                                'profile-following-count',
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onTap: () => _openFollowList(
                                                followers: false,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: stat(
                                                  profile.followingCount ?? 0,
                                                  'Following',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ]
                                        .map(
                                          (child) => ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minHeight: 24,
                                            ),
                                            child: Center(
                                              widthFactor: 1,
                                              heightFactor: 1,
                                              child: child,
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ),
                          if (!profile.isOnline &&
                              profile.lastActiveAt != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              context.tr('Active recently'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (profile.shortDescription.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Text(
                  profile.shortDescription.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            if (!own)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('profile-follow-button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _followBusy ? null : _toggleFollow,
                        icon: _followBusy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _followStatus == UserFollowStatus.accepted
                                    ? WicchuIcons.check
                                    : _followStatus == UserFollowStatus.pending
                                    ? WicchuIcons.clock
                                    : WicchuIcons.userPlus,
                                size: 18,
                              ),
                        label: Text(
                          context.tr(
                            _followStatus == UserFollowStatus.accepted
                                ? 'Following'
                                : _followStatus == UserFollowStatus.pending
                                ? 'Requested'
                                : 'Follow',
                          ),
                        ),
                      ),
                    ),
                    if (_followStatus == UserFollowStatus.accepted) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: context.tr('Post notifications'),
                        onPressed: _notificationBusy
                            ? null
                            : _openPersonNotificationPreferences,
                        icon: _notificationBusy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(WicchuIcons.bell),
                      ),
                    ],
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
                    const Icon(WicchuIcons.mapPin, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location!, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    final previous = _followStatus ?? UserFollowStatus.none;
    final previousCount = _followerCount ?? 0;
    final profile = await _profile;
    if (!mounted) return;
    final removing = previous != UserFollowStatus.none;
    final optimistic = removing
        ? UserFollowStatus.none
        : profile.isPrivate
        ? UserFollowStatus.pending
        : UserFollowStatus.accepted;
    setState(() {
      _followBusy = true;
      _followStatus = optimistic;
      if (previous == UserFollowStatus.accepted) {
        _followerCount = (previousCount - 1).clamp(0, 1 << 30);
      } else if (optimistic == UserFollowStatus.accepted) {
        _followerCount = (previousCount + 1).clamp(0, 1 << 30);
      }
    });
    try {
      final result = removing
          ? await widget.repository.unfollowUser(widget.userId)
          : await widget.repository.followUser(widget.userId);
      if (mounted) {
        setState(() {
          _followStatus = result.status;
          _followerCount = result.followerCount;
        });
        if (result.status == UserFollowStatus.pending) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Follow request sent'))),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _followStatus = previous;
        _followerCount = previousCount;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openPersonNotificationPreferences() async {
    setState(() => _notificationBusy = true);
    try {
      final current = await widget.repository
          .getPersonContentNotificationPreferences(widget.userId);
      if (!mounted) return;
      var notify = current.mode == ContentNotificationMode.all;
      var pushEnabled = current.pushEnabled;
      final result = await showModalBottomSheet<ScopedNotificationPreferences>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(context.tr('Post notifications')),
                    subtitle: Text(
                      context.tr('Choose alerts from this person'),
                    ),
                  ),
                  SwitchListTile(
                    value: notify,
                    title: Text(context.tr('New public posts')),
                    onChanged: (value) => setSheetState(() => notify = value),
                  ),
                  SwitchListTile(
                    value: pushEnabled,
                    title: Text(context.tr('Push notifications')),
                    subtitle: Text(context.tr('Receive alerts on your device')),
                    onChanged: notify
                        ? (value) => setSheetState(() => pushEnabled = value)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        current.copyWith(
                          mode: notify
                              ? ContentNotificationMode.all
                              : ContentNotificationMode.muted,
                          pushEnabled: pushEnabled,
                        ),
                      ),
                      child: Text(context.tr('Save')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (result != null) {
        await widget.repository.updatePersonContentNotificationPreferences(
          widget.userId,
          result,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Notification preferences saved.')),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _notificationBusy = false);
    }
  }

  Future<void> _openFollowList({required bool followers}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _UserFollowListPage(
          repository: widget.repository,
          userId: widget.userId,
          followers: followers,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openFollowRequests() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _FollowRequestsPage(repository: widget.repository),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _createPersonalPost() async {
    if (_composing) return;
    _composing = true;
    try {
      final viewer = await _viewer;
      if (!mounted || viewer?.id != widget.userId) return;
      final post = await openPersonalPostComposer(
        context,
        repository: widget.repository,
      );
      if (post != null && mounted) _reload();
    } finally {
      _composing = false;
    }
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

  Future<void> _findPeople() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindPeoplePage(repository: widget.repository),
      ),
    );
  }

  Future<void> _openChat() async {
    try {
      final conversation = await widget.repository.startDirectConversation(
        widget.userId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatPage(
            repository: widget.repository,
            conversation: conversation,
          ),
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

  Future<void> _reportMember() async {
    final report = await showContentReportDialog(
      context,
      title: 'Report profile',
    );
    if (report == null || !mounted) return;
    setState(() => _reporting = true);
    try {
      await widget.repository.reportMember(
        widget.userId,
        report.$1,
        category: report.$2,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Report submitted'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
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

class FindPeoplePage extends StatefulWidget {
  const FindPeoplePage({super.key, required this.repository});
  final CommunityRepository repository;

  @override
  State<FindPeoplePage> createState() => _FindPeoplePageState();
}

class _FindPeoplePageState extends State<FindPeoplePage>
    with BlockVisibilityListener<FindPeoplePage> {
  final _scrollController = ScrollController();
  final List<PeopleSearchResult> _people = [];
  Timer? _searchDelay;
  String _query = '';
  String? _nextCursor;
  Object? _error;
  bool _loading = false;
  int _requestGeneration = 0;

  @override
  CommunityRepository get visibilityRepository => widget.repository;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void reloadBlockVisibility() => _load(reset: true);

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300 && _nextCursor != null) {
      _load();
    }
  }

  void _search(String value) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 350), () {
      _query = value.trim();
      _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    if (reset) {
      setState(() {
        _people.clear();
        _nextCursor = null;
        _error = null;
        _loading = true;
      });
    } else {
      setState(() => _loading = true);
    }
    try {
      final page = await widget.repository.searchPeople(
        query: _query,
        cursor: reset ? null : _nextCursor,
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        final ids = _people.map((person) => person.id).toSet();
        _people.addAll(page.people.where((person) => ids.add(person.id)));
        _nextCursor = page.nextCursor;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Find people'))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.tr('Search people'),
              prefixIcon: const Icon(WicchuIcons.magnifyingGlass),
            ),
          ),
        ),
        Expanded(
          child: _people.isEmpty && _loading
              ? const Center(child: CircularProgressIndicator())
              : _people.isEmpty && _error != null
              ? Center(
                  child: TextButton(
                    onPressed: () => _load(reset: true),
                    child: Text(context.tr('Retry')),
                  ),
                )
              : _people.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? context.tr('Find people on Wicchu here.')
                          : context.tr('No people found.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount:
                      _people.length + (_loading || _error != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _people.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _loading
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: _load,
                                  child: Text(context.tr('Retry')),
                                ),
                        ),
                      );
                    }
                    final person = _people[index];
                    final username = person.userName.isEmpty
                        ? ''
                        : '@${person.userName}';
                    final shared = context.trCount(
                      person.sharedCommunityCount,
                      singular: '{count} shared community',
                      plural: '{count} shared communities',
                    );
                    return ListTile(
                      leading: UserAvatar(
                        name: person.name,
                        imageUrl: person.avatarUrl,
                        radius: 22,
                      ),
                      title: Text(person.name),
                      subtitle: Text(
                        username.isEmpty ? shared : '$username · $shared',
                      ),
                      trailing: const Icon(WicchuIcons.caretRight),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberProfilePage(
                            userId: person.id,
                            repository: widget.repository,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
