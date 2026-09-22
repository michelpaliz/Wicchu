import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../domain/auth_gateway.dart';
import '../../localization/app_language.dart';
import '../../theme/theme_menu.dart';
import '../../widgets/wicchu_logo.dart';
import '../admin/create_community_page.dart';
import '../community/community_page.dart';
import '../community/community_avatar.dart';
import '../community/comments_sheet.dart';
import '../community/create_post_page.dart';
import '../community/post_card.dart';
import '../community/post_collection_page.dart';
import '../community/post_detail_page.dart';
import '../community/post_share.dart';
import '../settings/account_settings_page.dart';

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
  int _homeRevision = 0;
  int _exploreRevision = 0;
  int _profileRevision = 0;
  int _activityRevision = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        key: ValueKey('home-$_homeRevision'),
        repository: widget.repository,
        onCommunitiesChanged: () => setState(() {
          _exploreRevision++;
          _profileRevision++;
        }),
      ),
      _ExploreTab(
        key: ValueKey('explore-$_exploreRevision'),
        repository: widget.repository,
        onCommunitiesChanged: () => setState(() {
          _homeRevision++;
          _profileRevision++;
        }),
      ),
      _ActivityTab(
        key: ValueKey('activity-$_activityRevision'),
        repository: widget.repository,
      ),
      _ProfileTab(
        repository: widget.repository,
        authGateway: widget.authGateway,
        onSignedOut: widget.onSignedOut,
        refreshVersion: _profileRevision,
        onCommunityCreated: () => setState(() {
          _homeRevision++;
          _exploreRevision++;
        }),
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          _index = value;
          if (value == 2) _activityRevision++;
          if (value == 3) _profileRevision++;
        }),
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
  const _HomeTab({
    super.key,
    required this.repository,
    required this.onCommunitiesChanged,
  });
  final CommunityRepository repository;
  final VoidCallback onCommunitiesChanged;

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
  Timer? _searchDelay;

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

  @override
  void dispose() {
    _searchDelay?.cancel();
    super.dispose();
  }

  void _updateSearch(String value) {
    setState(() => _query = value);
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(_reload);
    });
  }

  Future<_HomeFeedData> _loadData() async {
    final communities = await widget.repository.listJoinedCommunities();
    final results = await Future.wait([
      widget.repository.listFollowingPosts(query: _query),
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
    try {
      final categories = await widget.repository.listCategories(community.id);
      if (!mounted) return;
      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('No categories found'))),
        );
        return;
      }
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _openCommunity(Community community) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunityPage(community: community, repository: widget.repository),
      ),
    );
    if (!mounted) return;
    setState(_reload);
    widget.onCommunitiesChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const WicchuTitle(),
        actions: [
          IconButton(
            tooltip: context.tr(_showSearch ? 'Close search' : 'Search posts'),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchDelay?.cancel();
                _query = '';
                _reload();
              }
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              error: snapshot.error!,
              onRetry: () => setState(_reload),
            );
          }
          final data = snapshot.data!;
          final communities = data.communities;
          final town =
              communities.firstOrNull?.town.name ?? context.tr('Your town');
          final normalizedQuery = _query.trim().toLowerCase();
          final categoryNames = [
            'All',
            ...data.categories.values.map((category) => category.name).toSet(),
          ];
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              try {
                await _data;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        context.tr(
                          'Join a community to see local updates here.',
                        ),
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
                              CommunityAvatar(community: community, radius: 26),
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
                                      context.trCount(
                                        community.memberCount,
                                        singular: '{count} neighbor',
                                        plural: '{count} neighbors',
                                      ),
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
                    onChanged: _updateSearch,
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
                      for (final category in categoryNames) ...[
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
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final post in filteredPosts) ...[
                  PostCard(
                    onTap: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailPage(
                              postId: post.id,
                              repository: widget.repository,
                              initialPost: post,
                              category:
                                  data.categories[post.categoryId]?.name ??
                                  'Post',
                              icon:
                                  data.categories[post.categoryId]?.icon ??
                                  '💬',
                              community:
                                  communityById[post.communityId]?.name ??
                                  'Wicchu',
                            ),
                          ),
                        ).then((_) {
                          if (mounted) setState(_reload);
                        }),
                    category: data.categories[post.categoryId]?.name ?? 'Post',
                    icon: data.categories[post.categoryId]?.icon ?? '💬',
                    community:
                        communityById[post.communityId]?.name ?? 'Wicchu',
                    author: post.authorName,
                    time: formatPostTime(context, post.createdAt),
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
                    onShare: () => sharePost(
                      widget.repository,
                      post,
                      communityName:
                          communityById[post.communityId]?.name ?? 'Wicchu',
                    ),
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
            ),
          );
        },
      ),
    );
  }
}

class _ExploreTab extends StatefulWidget {
  const _ExploreTab({
    super.key,
    required this.repository,
    required this.onCommunitiesChanged,
  });
  final CommunityRepository repository;
  final VoidCallback onCommunitiesChanged;

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  late Future<List<Community>> _communities;
  final _saving = <String>{};
  Timer? _searchDelay;
  bool _showSearch = false;
  String _query = '';
  bool _usingLocation = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _communities = widget.repository.listCommunities(query: _query);
    _usingLocation = false;
  }

  Future<void> _findNearby() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!(preferences.getBool('location_discovery') ?? true)) {
        throw Exception('Enable nearby discovery in Settings first.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Enable location services to discover nearby communities.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required for nearby discovery.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _usingLocation = true;
        _communities = widget.repository.listNearbyCommunities(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _communities;
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _reload();
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Explore')),
      actions: [
        IconButton(
          tooltip: context.tr(
            _usingLocation ? 'Show all communities' : 'Use my location',
          ),
          onPressed: _usingLocation ? () => setState(_reload) : _findNearby,
          icon: Icon(_usingLocation ? Icons.location_on : Icons.my_location),
        ),
        IconButton(
          tooltip: context.tr(
            _showSearch ? 'Close search' : 'Search communities',
          ),
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchDelay?.cancel();
              _query = '';
              _reload();
            }
          }),
          icon: Icon(_showSearch ? Icons.close : Icons.search),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_showSearch) ...[
            TextField(
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: context.tr('Search communities'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
              if (snapshot.hasError) {
                return _LoadError(
                  error: snapshot.error!,
                  onRetry: () => setState(_reload),
                );
              }
              final communities = snapshot.data ?? const <Community>[];
              if (communities.isEmpty) {
                return Text(context.tr('No communities found'));
              }
              return Column(
                children: [
                  for (final community in communities)
                    Card(
                      child: ListTile(
                        onTap: () =>
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommunityPage(
                                  community: community,
                                  repository: widget.repository,
                                ),
                              ),
                            ).then((_) {
                              if (!mounted) return;
                              setState(_reload);
                              widget.onCommunitiesChanged();
                            }),
                        leading: CommunityAvatar(community: community),
                        title: Text(community.name),
                        subtitle: Text(
                          '${context.trCount(community.memberCount, singular: '{count} member', plural: '{count} members')}${community.distanceKm == null ? '' : ' · ${community.distanceKm!.toStringAsFixed(1)} km'}',
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
        ],
      ),
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
      if (mounted) {
        setState(_reload);
        widget.onCommunitiesChanged();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(community.id));
    }
  }
}

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  late Future<NotificationFeed> _feed = widget.repository.listNotifications();

  void _reload() {
    _feed = widget.repository.listNotifications();
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _feed;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Activity')),
      actions: [
        FutureBuilder<NotificationFeed>(
          future: _feed,
          builder: (context, snapshot) => TextButton(
            onPressed: (snapshot.data?.unreadCount ?? 0) > 0
                ? _markAllRead
                : null,
            child: Text(context.tr('Mark all read')),
          ),
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
          return _LoadError(
            error: snapshot.error!,
            onRetry: () => setState(_reload),
          );
        }
        final notifications = snapshot.data?.items ?? const [];
        if (notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(context.tr('No activity yet'))),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
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
                subtitle: Text(formatPostTime(context, notification.createdAt)),
                trailing: notification.isRead
                    ? null
                    : const Icon(Icons.circle, size: 10),
                onTap: () => _openNotification(notification),
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
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _openNotification(CommunityNotification notification) async {
    if (!notification.isRead) {
      await _markRead(notification.id);
    }
    if (!mounted) return;
    if (notification.postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Post unavailable'))));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          postId: notification.postId,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _markAllRead() async {
    try {
      await widget.repository.markAllNotificationsRead();
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    required this.repository,
    required this.authGateway,
    required this.onSignedOut,
    required this.onCommunityCreated,
    required this.refreshVersion,
  });
  final CommunityRepository repository;
  final AuthGateway authGateway;
  final VoidCallback onSignedOut;
  final VoidCallback onCommunityCreated;
  final int refreshVersion;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late Future<WicchuProfile> _profile = widget.repository.getProfile();

  Future<void> _refreshProfile() async {
    setState(() {
      _profile = widget.repository.getProfile();
    });
    try {
      await _profile;
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _profile = widget.repository.getProfile();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('You'))),
    body: RefreshIndicator(
      onRefresh: _refreshProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          FutureBuilder<WicchuProfile>(
            future: _profile,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _LoadError(
                  error: snapshot.error!,
                  onRetry: () => setState(() {
                    _profile = widget.repository.getProfile();
                  }),
                );
              }
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
                    '${context.trCount(profile.communityCount, singular: '{count} community', plural: '{count} communities')} · '
                    '${context.trCount(profile.postCount, singular: '{count} post', plural: '{count} posts')}',
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
          _ProfileRow(
            icon: Icons.add_circle_outline,
            label: 'Create a community',
            onTap: _createCommunity,
          ),
          _ProfileRow(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
            ),
          ),
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
          _ProfileRow(
            icon: Icons.help_outline,
            label: 'Help',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpPage()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(context.tr('Log out')),
            onTap: _logout,
          ),
        ],
      ),
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

  Future<void> _createCommunity() async {
    final community = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(repository: widget.repository),
      ),
    );
    if (!mounted || community == null) return;
    setState(() {
      _profile = widget.repository.getProfile();
    });
    widget.onCommunityCreated();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunityPage(community: community, repository: widget.repository),
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

class _CommunityCollectionPage extends StatefulWidget {
  const _CommunityCollectionPage({
    required this.title,
    required this.repository,
    required this.loadCommunities,
  });

  final String title;
  final CommunityRepository repository;
  final Future<List<Community>> Function() loadCommunities;

  @override
  State<_CommunityCollectionPage> createState() =>
      _CommunityCollectionPageState();
}

class _CommunityCollectionPageState extends State<_CommunityCollectionPage> {
  late Future<List<Community>> _communities = widget.loadCommunities();

  Future<void> _refresh() async {
    setState(() {
      _communities = widget.loadCommunities();
    });
    try {
      await _communities;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr(widget.title))),
    body: FutureBuilder<List<Community>>(
      future: _communities,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(error: snapshot.error!, onRetry: _refresh);
        }
        final communities = snapshot.data ?? const [];
        if (communities.isEmpty) {
          return Center(child: Text(context.tr('No communities found')));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              return Card(
                child: ListTile(
                  leading: CommunityAvatar(community: community),
                  title: Text(community.name),
                  subtitle: Text(
                    context.trCount(
                      community.memberCount,
                      singular: '{count} member',
                      plural: '{count} members',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityPage(
                            community: community,
                            repository: widget.repository,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) _refresh();
                      }),
                ),
              );
            },
          ),
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.trError(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('Retry')),
          ),
        ],
      ),
    ),
  );
}
