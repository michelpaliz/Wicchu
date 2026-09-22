import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../domain/auth_gateway.dart';
import '../../localization/app_language.dart';
import '../../theme/theme_menu.dart';
import '../community/community_page.dart';
import '../community/comments_sheet.dart';
import '../community/create_post_page.dart';
import '../community/post_card.dart';
import '../community/post_collection_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.repository,
    required this.authGateway,
    required this.onSignedOut,
  });
  final CommunityRepository repository;
  final AuthGateway authGateway;
  final VoidCallback onSignedOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(repository: widget.repository),
      _ExploreTab(repository: widget.repository),
      _ActivityTab(repository: widget.repository),
      _ProfileTab(
        repository: widget.repository,
        authGateway: widget.authGateway,
        onSignedOut: widget.onSignedOut,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.tr('Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: context.tr('Explore'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: context.tr('Activity'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.tr('You'),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.repository});
  final CommunityRepository repository;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeFeedData {
  const _HomeFeedData({
    required this.communities,
    required this.posts,
    required this.categories,
  });

  final List<Community> communities;
  final List<CommunityPost> posts;
  final Map<String, CommunityCategory> categories;
}

class _HomeTabState extends State<_HomeTab> {
  late Future<_HomeFeedData> _data;

  String _category = 'All';
  String _query = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = _loadData();
  }

  Future<_HomeFeedData> _loadData() async {
    final communities = await widget.repository.listJoinedCommunities();
    final results = await Future.wait([
      widget.repository.listFollowingPosts(),
      ...communities.map(
        (community) => widget.repository.listCategories(community.id),
      ),
    ]);
    final posts = results.first.cast<CommunityPost>();
    final categories = <String, CommunityCategory>{};
    for (final result in results.skip(1)) {
      for (final category in result.cast<CommunityCategory>()) {
        categories[category.id] = category;
      }
    }
    return _HomeFeedData(
      communities: communities,
      posts: posts,
      categories: categories,
    );
  }

  Future<void> _createPost(Community community) async {
    final categories = await widget.repository.listCategories(community.id);
    if (!mounted) return;
    final post = await Navigator.push<CommunityPost>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          community: community,
          repository: widget.repository,
          categories: categories,
        ),
      ),
    );
    if (post != null && mounted) setState(_reload);
  }

  void _openCommunity(Community community) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunityPage(community: community, repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wicchu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: context.tr(_showSearch ? 'Close search' : 'Search posts'),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _query = '';
            }),
            icon: Icon(_showSearch ? Icons.close : Icons.search_rounded),
          ),
          const ThemeMenu(),
          const LanguageMenu(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FutureBuilder<_HomeFeedData>(
        future: _data,
        builder: (context, snapshot) {
          final community = snapshot.data?.communities.firstOrNull;
          if (community == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _createPost(community),
            icon: const Icon(Icons.add),
            label: Text(context.tr('New post')),
          );
        },
      ),
      body: FutureBuilder<_HomeFeedData>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final communities = data.communities;
          final town =
              communities.firstOrNull?.town.name ?? context.tr('Your town');
          final normalizedQuery = _query.trim().toLowerCase();
          final communityById = {
            for (final community in communities) community.id: community,
          };
          final filteredPosts = data.posts.where((post) {
            final category = data.categories[post.categoryId];
            final matchesCategory =
                _category == 'All' || category?.name == _category;
            final matchesQuery =
                normalizedQuery.isEmpty ||
                post.text.toLowerCase().contains(normalizedQuery) ||
                post.authorName.toLowerCase().contains(normalizedQuery) ||
                (category?.name.toLowerCase().contains(normalizedQuery) ??
                    false);
            return matchesCategory && matchesQuery;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 108),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('YOUR NEIGHBORHOOD'),
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Good things happen nearby.'),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('The latest from {town} and your communities.', {
                  'town': town,
                }),
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                context.tr('Your communities'),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (communities.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      context.tr('Join a community to see local updates here.'),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                for (final community in communities) ...[
                  Card(
                    color: scheme.primaryContainer,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openCommunity(community),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: scheme.surface,
                              child: Icon(
                                Icons.location_city_rounded,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    community.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context.tr('{count} neighbors', {
                                      'count': '${community.memberCount}',
                                    }),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 17,
                              color: scheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 18),
              Text(
                context.tr('Neighborhood feed'),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Updates and finds from around you'),
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (_showSearch) ...[
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.tr('Search local posts'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in const [
                      'All',
                      'News',
                      'Marketplace',
                    ]) ...[
                      ChoiceChip(
                        label: Text(context.tr(category)),
                        selected: _category == category,
                        showCheckmark: false,
                        selectedColor: scheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: _category == category
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                        onSelected: (_) => setState(() => _category = category),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final post in filteredPosts) ...[
                PostCard(
                  category: data.categories[post.categoryId]?.name ?? 'Post',
                  icon: data.categories[post.categoryId]?.icon ?? '💬',
                  community: communityById[post.communityId]?.name ?? 'Wicchu',
                  author: post.authorName,
                  time: formatPostTime(post.createdAt),
                  text: post.text,
                  likes: post.reactionCount,
                  comments: post.commentCount,
                  media: post.media,
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
                ),
                const SizedBox(height: 12),
              ],
              if (filteredPosts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 32,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('No posts found'),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('Try another search or category.'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExploreTab extends StatefulWidget {
  const _ExploreTab({required this.repository});
  final CommunityRepository repository;

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  late Future<List<Community>> _communities;
  final _saving = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _communities = widget.repository.listCommunities();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Explore')),
      actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '📍 ${context.tr('Near you')}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Community>>(
          future: _communities,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Text(snapshot.error.toString());
            final communities = snapshot.data ?? const <Community>[];
            if (communities.isEmpty) {
              return Text(context.tr('No communities found'));
            }
            return Column(
              children: [
                for (final community in communities)
                  Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityPage(
                            community: community,
                            repository: widget.repository,
                          ),
                        ),
                      ).then((_) => setState(_reload)),
                      leading: const CircleAvatar(child: Text('🏘')),
                      title: Text(community.name),
                      subtitle: Text(
                        context.tr('{count} members', {
                          'count': '${community.memberCount}',
                        }),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed:
                            _saving.contains(community.id) ||
                                community.myRole == CommunityRole.owner
                            ? null
                            : () => _toggleMembership(community),
                        child: _saving.contains(community.id)
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                context.tr(
                                  community.myRole == CommunityRole.owner
                                      ? 'Owner'
                                      : community.isJoined
                                      ? 'Joined'
                                      : 'Join',
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          context.tr('Popular near you'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('🐕 ${context.tr('Animal Lovers')}')),
            Chip(label: Text('⚽ ${context.tr('Football')}')),
            Chip(label: Text('🎓 ${context.tr('Students')}')),
            Chip(label: Text('🚴 ${context.tr('Cycling')}')),
          ],
        ),
      ],
    ),
  );

  Future<void> _toggleMembership(Community community) async {
    setState(() => _saving.add(community.id));
    try {
      if (community.isJoined) {
        await widget.repository.leaveCommunity(community.id);
      } else {
        await widget.repository.joinCommunity(community.id);
      }
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(community.id));
    }
  }
}

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({required this.repository});

  final CommunityRepository repository;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  late Future<NotificationFeed> _feed = widget.repository.listNotifications();

  void _reload() {
    _feed = widget.repository.listNotifications();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Activity')),
      actions: [
        TextButton(
          onPressed: _markAllRead,
          child: Text(context.tr('Mark all read')),
        ),
      ],
    ),
    body: FutureBuilder<NotificationFeed>(
      future: _feed,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final notifications = snapshot.data?.items ?? const [];
        if (notifications.isEmpty) {
          return Center(child: Text(context.tr('No activity yet')));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final icon =
                  notification.type == CommunityNotificationType.postComment
                  ? Icons.chat_bubble_outline
                  : Icons.favorite_border;
              return ListTile(
                tileColor: notification.isRead
                    ? null
                    : Theme.of(context).colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(
                  backgroundImage: notification.actorAvatarUrl == null
                      ? null
                      : NetworkImage(notification.actorAvatarUrl!),
                  child: notification.actorAvatarUrl == null
                      ? Icon(icon)
                      : null,
                ),
                title: Text(
                  '${notification.actorName} ${context.tr(notification.message)}',
                ),
                subtitle: Text(formatPostTime(notification.createdAt)),
                trailing: notification.isRead
                    ? null
                    : const Icon(Icons.circle, size: 10),
                onTap: notification.isRead
                    ? null
                    : () => _markRead(notification.id),
              );
            },
          ),
        );
      },
    ),
  );

  Future<void> _markRead(String id) async {
    try {
      await widget.repository.markNotificationRead(id);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.repository.markAllNotificationsRead();
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    required this.repository,
    required this.authGateway,
    required this.onSignedOut,
  });
  final CommunityRepository repository;
  final AuthGateway authGateway;
  final VoidCallback onSignedOut;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final Future<WicchuProfile> _profile = widget.repository.getProfile();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('You'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FutureBuilder<WicchuProfile>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Text(snapshot.error.toString());
            final profile = snapshot.data!;
            return Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('@${profile.userName}'),
                const SizedBox(height: 8),
                Text(
                  context.tr('{communities} Communities · {posts} Posts', {
                    'communities': '${profile.communityCount}',
                    'posts': '${profile.postCount}',
                  }),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _ProfileRow(
          icon: Icons.groups_outlined,
          label: 'My communities',
          onTap: () => _openCommunities(
            'My communities',
            widget.repository.listJoinedCommunities,
          ),
        ),
        _ProfileRow(
          icon: Icons.article_outlined,
          label: 'My posts',
          onTap: () => _openPosts('My posts', widget.repository.listMyPosts),
        ),
        _ProfileRow(
          icon: Icons.bookmark_border,
          label: 'Saved posts',
          onTap: () =>
              _openPosts('Saved posts', widget.repository.listSavedPosts),
        ),
        const Divider(height: 28),
        _ProfileRow(
          icon: Icons.shield_outlined,
          label: 'Communities I manage',
          onTap: () => _openCommunities(
            'Communities I manage',
            widget.repository.listManagedCommunities,
          ),
        ),
        const _ProfileRow(icon: Icons.settings_outlined, label: 'Settings'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language_rounded),
          title: Text(context.tr('Language')),
          trailing: const LanguageMenu(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.brightness_6_outlined),
          title: Text(context.tr('Appearance')),
          trailing: const ThemeMenu(showLabel: true),
        ),
        const _ProfileRow(icon: Icons.help_outline, label: 'Help'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: Text(context.tr('Log out')),
          onTap: _logout,
        ),
      ],
    ),
  );

  void _openPosts(String title, Future<List<CommunityPost>> Function() loader) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostCollectionPage(
          title: title,
          repository: widget.repository,
          loadPosts: loader,
        ),
      ),
    );
  }

  void _openCommunities(
    String title,
    Future<List<Community>> Function() loader,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CommunityCollectionPage(
          title: title,
          repository: widget.repository,
          loadCommunities: loader,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.authGateway.signOut();
    if (mounted) widget.onSignedOut();
  }
}

class _CommunityCollectionPage extends StatelessWidget {
  const _CommunityCollectionPage({
    required this.title,
    required this.repository,
    required this.loadCommunities,
  });

  final String title;
  final CommunityRepository repository;
  final Future<List<Community>> Function() loadCommunities;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr(title))),
    body: FutureBuilder<List<Community>>(
      future: loadCommunities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final communities = snapshot.data ?? const [];
        if (communities.isEmpty) {
          return Center(child: Text(context.tr('No communities found')));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: communities.length,
          itemBuilder: (context, index) {
            final community = communities[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Text('🏘')),
                title: Text(community.name),
                subtitle: Text(
                  context.tr('{count} members', {
                    'count': '${community.memberCount}',
                  }),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityPage(
                      community: community,
                      repository: repository,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(context.tr(label)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
