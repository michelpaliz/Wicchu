import '../../widgets/feed_filter_bar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../domain/auth_gateway.dart';
import '../../localization/app_language.dart';
import '../../services/push_notification_service.dart';
import '../../theme/theme_menu.dart';
import '../../widgets/wicchu_logo.dart';
import '../admin/create_community_page.dart';
import '../community/community_page.dart';
import '../community/community_profile_page.dart';
import '../community/community_avatar.dart';
import '../community/community_invitations_page.dart';
import '../community/comments_sheet.dart';
import '../community/create_post_page.dart';
import '../community/post_card.dart';
import '../community/post_collection_page.dart';
import '../community/post_detail_page.dart';
import '../community/post_share.dart';
import '../community/user_avatar.dart';
import '../settings/account_settings_page.dart';
import '../promotions/promotions_page.dart';
import '../profile/member_profile_page.dart';

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
  final _homeKey = GlobalKey<_HomeTabState>();
  int _exploreRevision = 0;
  int _profileRevision = 0;
  int _activityRevision = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        key: _homeKey,
        onExplore: () => _selectDestination(1),
        repository: widget.repository,
        onCommunitiesChanged: () => setState(() {
          _exploreRevision++;
          _profileRevision++;
        }),
      ),
      _ExploreTab(
        key: ValueKey('explore-$_exploreRevision'),
        repository: widget.repository,
        onCommunitiesChanged: () {
          _homeKey.currentState?.refresh();
          setState(() => _profileRevision++);
        },
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
        onCommunityCreated: () {
          _homeKey.currentState?.refresh();
          setState(() => _exploreRevision++);
        },
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _CompactBottomNavigation(
        selectedIndex: _index,
        onSelected: _selectDestination,
        onCreatePost: () => _homeKey.currentState?.startPost(),
      ),
    );
  }

  void _selectDestination(int value) {
    setState(() {
      _index = value;
      if (value == 2) _activityRevision++;
      if (value == 3) _profileRevision++;
    });
  }
}

class _CompactBottomNavigation extends StatelessWidget {
  const _CompactBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.onCreatePost,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 68 + MediaQuery.paddingOf(context).bottom,
      child: Stack(
        children: [
          Positioned.fill(
            top: 8,
            child: Material(
              color: scheme.surface,
              elevation: 3,
              shadowColor: scheme.shadow.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _CompactNavigationItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: context.tr('Home'),
                      selected: selectedIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                    _CompactNavigationItem(
                      icon: CupertinoIcons.compass,
                      selectedIcon: CupertinoIcons.compass_fill,
                      label: context.tr('Explore'),
                      selected: selectedIndex == 1,
                      onTap: () => onSelected(1),
                    ),
                    const Spacer(),
                    _CompactNavigationItem(
                      icon: CupertinoIcons.bell,
                      selectedIcon: CupertinoIcons.bell_fill,
                      label: context.tr('Activity'),
                      selected: selectedIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                    _CompactNavigationItem(
                      icon: CupertinoIcons.person,
                      selectedIcon: CupertinoIcons.person_fill,
                      label: context.tr('You'),
                      selected: selectedIndex == 3,
                      onTap: () => onSelected(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _CreatePostNavigationItem(
              label: context.tr('Post'),
              onTap: onCreatePost,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactNavigationItem extends StatelessWidget {
  const _CompactNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, size: 20, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePostNavigationItem extends StatelessWidget {
  const _CreatePostNavigationItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: scheme.primary,
        elevation: 6,
        shadowColor: scheme.shadow.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(CupertinoIcons.plus, color: scheme.onPrimary, size: 24),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    super.key,
    required this.repository,
    required this.onCommunitiesChanged,
    required this.onExplore,
  });
  final VoidCallback onExplore;
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
    required this.members,
    required this.onlineMembers,
  });

  final List<Community> communities;
  final List<CommunityPost> posts;
  final Map<String, CommunityCategory> categories;
  final List<CommunityMember> members;
  final List<CommunityMember> onlineMembers;
}

class _HomeTabState extends State<_HomeTab> {
  late Future<_HomeFeedData> _data;
  Timer? _searchDelay;

  final _feedScroll = ScrollController();
  String? _selectionKey;

  String _category = 'All';
  String _query = '';
  String? _selectedCommunityId;
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
    _feedScroll.dispose();
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
    final profile = await widget.repository.getProfile();
    final preferences = await SharedPreferences.getInstance();
    _selectionKey = 'currentCommunityId:${profile.id}';
    final savedId =
        _selectedCommunityId ?? preferences.getString(_selectionKey!);
    _selectedCommunityId = communities.any((c) => c.id == savedId)
        ? savedId
        : communities.length == 1
        ? communities.first.id
        : null;
    if (_selectedCommunityId != null) {
      await preferences.setString(_selectionKey!, _selectedCommunityId!);
    } else {
      await preferences.remove(_selectionKey!);
    }

    final memberFutures = communities.map(
      (community) => widget.repository.listMembers(community.id),
    );
    final results = await Future.wait([
      widget.repository.listFollowingPosts(query: _query),
      ...communities.map(
        (community) => widget.repository.listCategories(community.id),
      ),
    ]);
    final memberLists = await Future.wait(memberFutures);
    final membersByUserId = <String, CommunityMember>{};
    final onlineByUserId = <String, CommunityMember>{};
    for (final member in memberLists.expand((members) => members)) {
      membersByUserId.putIfAbsent(
        '${member.communityId}:${member.userId}',
        () => member,
      );
      if (member.isOnline && member.userId != profile.id) {
        onlineByUserId.putIfAbsent(
          '${member.communityId}:${member.userId}',
          () => member,
        );
      }
    }
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
      members: membersByUserId.values.toList(growable: false),
      onlineMembers: onlineByUserId.values.toList(growable: false),
    );
  }

  void refresh() {
    if (mounted) setState(_reload);
  }

  Future<void> startPost() async {
    try {
      final data = await _data;
      if (!mounted) return;
      if (data.communities.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Join a community before creating a post.'),
            ),
          ),
        );
        return;
      }
      final active = data.communities
          .where((c) => c.id == _selectedCommunityId)
          .firstOrNull;
      if (active != null) {
        await _createPost(active);
      } else {
        await _startPost(data.communities);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
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
      final selectedCategory = await showModalBottomSheet<CommunityCategory>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  sheetContext.tr('What do you want to publish?'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final category in categories)
                ListTile(
                  leading: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(sheetContext.tr(category.name)),
                  onTap: () => Navigator.pop(sheetContext, category),
                ),
            ],
          ),
        ),
      );
      if (selectedCategory == null || !mounted) return;
      final post = await Navigator.push<CommunityPost>(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePostPage(
            community: community,
            repository: widget.repository,
            categories: categories,
            initialCategory: selectedCategory,
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

  Future<void> _startPost(List<Community> communities) async {
    if (communities.isEmpty) return;
    if (communities.length == 1) {
      await _createPost(communities.first);
      return;
    }
    final selected = await showModalBottomSheet<Community>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                sheetContext.tr('Choose a community'),
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final community in communities)
              ListTile(
                title: Text(community.name),
                subtitle: Text(community.town.name),
                onTap: () => Navigator.pop(sheetContext, community),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) await _createPost(selected);
  }

  Future<void> _createHomeCommunity() async {
    final created = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(repository: widget.repository),
      ),
    );
    if (created != null && mounted) {
      _selectedCommunityId = created.id;
      widget.onCommunitiesChanged();
      setState(_reload);
    }
  }

  Future<void> _chooseCommunity(List<Community> communities) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                context.tr('My communities'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final community in communities)
              ListTile(
                leading: Icon(
                  community.id == _selectedCommunityId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(community.name),
                subtitle: Text(community.town.name),
                onTap: () => Navigator.pop(sheetContext, community.id),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: Text(context.tr('Explore communities')),
              onTap: () => Navigator.pop(sheetContext, '__explore'),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.tr('Create a community')),
              onTap: () => Navigator.pop(sheetContext, '__create'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == '__explore') {
      widget.onExplore();
      return;
    }
    if (selected == '__create') {
      await _createHomeCommunity();
      return;
    }
    setState(() {
      _selectedCommunityId = selected;
      _category = 'All';
      _query = '';
      _showSearch = false;
    });
    if (_feedScroll.hasClients) _feedScroll.jumpTo(0);
    final preferences = await SharedPreferences.getInstance();
    if (_selectionKey != null) {
      await preferences.setString(_selectionKey!, selected);
    }
  }

  Widget _homeOnboarding(List<Community> communities) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.holiday_village_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            context.tr(
              communities.isEmpty
                  ? 'Find your community'
                  : 'Select a community',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              communities.isEmpty
                  ? 'Discover communities nearby, join and connect with your neighbors.'
                  : 'Choose a community to see its posts and neighbors.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: communities.isEmpty
                ? widget.onExplore
                : () => _chooseCommunity(communities),
            icon: Icon(
              communities.isEmpty
                  ? Icons.explore_outlined
                  : Icons.groups_outlined,
            ),
            label: Text(
              context.tr(
                communities.isEmpty
                    ? 'Explore communities'
                    : 'Select a community',
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _createHomeCommunity,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Create a community')),
          ),
        ],
      ),
    ),
  );

  Future<void> _showMembers(List<CommunityMember> members) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  sheetContext.tr('Neighbors'),
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final member in members)
                ListTile(
                  leading: Badge(
                    isLabelVisible: member.isOnline,
                    backgroundColor: Colors.green,
                    smallSize: 10,
                    child: UserAvatar(
                      name: member.name,
                      imageUrl: member.avatarUrl,
                      radius: 21,
                    ),
                  ),
                  title: Text(member.name),
                  subtitle: member.isOnline
                      ? Text(sheetContext.tr('Online now'))
                      : member.lastActiveAt != null
                      ? Text(sheetContext.tr('Active recently'))
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberProfilePage(
                          repository: widget.repository,
                          userId: member.userId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: FutureBuilder<_HomeFeedData>(
          future: _data,
          builder: (context, snapshot) {
            final communities = snapshot.data?.communities ?? [];
            if (communities.isEmpty) return const WicchuTitle();
            final active = communities
                .where((c) => c.id == _selectedCommunityId)
                .firstOrNull;
            return InkWell(
              onTap: () => _chooseCommunity(communities),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      active?.name ?? context.tr('Select a community'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: context.tr(
              _selectedCommunityId == null
                  ? 'Explore communities'
                  : _showSearch
                  ? 'Close search'
                  : 'Search posts',
            ),
            onPressed: _selectedCommunityId == null
                ? widget.onExplore
                : () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchDelay?.cancel();
                      _query = '';
                      _reload();
                    }
                  }),
            icon: Icon(_showSearch ? Icons.close : Icons.search_rounded),
          ),
          FutureBuilder<_HomeFeedData>(
            future: _data,
            builder: (context, snapshot) {
              final active = snapshot.data?.communities
                  .where((c) => c.id == _selectedCommunityId)
                  .firstOrNull;
              if (active == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: context.tr('Community details'),
                icon: const Icon(Icons.holiday_village_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityProfilePage(
                        community: active,
                        repository: widget.repository,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  widget.onCommunitiesChanged();
                  setState(_reload);
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
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
          if (communities.isEmpty || _selectedCommunityId == null) {
            return _homeOnboarding(communities);
          }
          final visibleCommunities = communities
              .where((c) => c.id == _selectedCommunityId)
              .toList();
          final visibleCommunityIds = visibleCommunities
              .map((community) => community.id)
              .toSet();
          final visibleOnlineMembers = {
            for (final member in data.onlineMembers)
              if (visibleCommunityIds.contains(member.communityId))
                member.userId: member,
          }.values.toList(growable: false);
          final normalizedQuery = _query.trim().toLowerCase();
          final categoryNames = [
            'All',
            ...data.categories.values
                .where(
                  (category) =>
                      visibleCommunityIds.contains(category.communityId),
                )
                .map((category) => category.name)
                .toSet(),
          ];
          const categoryOrder = ['All', 'General', 'News', 'Events', 'Housing'];
          int categoryRank(String name) {
            final rank = categoryOrder.indexOf(name);
            return rank < 0 ? categoryOrder.length : rank;
          }

          categoryNames.sort(
            (a, b) => categoryRank(a).compareTo(categoryRank(b)),
          );
          final communityById = {
            for (final community in communities) community.id: community,
          };
          final filteredPosts = data.posts.where((post) {
            final category = data.categories[post.categoryId];
            final matchesTown = visibleCommunityIds.contains(post.communityId);
            final matchesCategory =
                _category == 'All' || category?.name == _category;
            final matchesQuery =
                normalizedQuery.isEmpty ||
                post.text.toLowerCase().contains(normalizedQuery) ||
                post.authorName.toLowerCase().contains(normalizedQuery) ||
                (category?.name.toLowerCase().contains(normalizedQuery) ??
                    false);
            return matchesTown && matchesCategory && matchesQuery;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              try {
                await _data;
              } catch (_) {}
            },
            child: CustomScrollView(
              controller: _feedScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.list(
                    children: [
                      if (visibleOnlineMembers.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          height:
                              56 +
                              MediaQuery.textScalerOf(context).scale(12) * 1.5,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: visibleOnlineMembers.length > 5
                                ? 6
                                : visibleOnlineMembers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              if (index == 5) {
                                final remaining =
                                    visibleOnlineMembers.length - 5;
                                return Semantics(
                                  button: true,
                                  label: context.tr(
                                    'View all online neighbors',
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () =>
                                        _showMembers(visibleOnlineMembers),
                                    child: SizedBox(
                                      width: 58,
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor:
                                                scheme.primaryContainer,
                                            child: Icon(
                                              CupertinoIcons.person_2,
                                              size: 22,
                                              color: scheme.onPrimaryContainer,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '+$remaining',
                                            style: textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final member = visibleOnlineMembers[index];
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MemberProfilePage(
                                      repository: widget.repository,
                                      userId: member.userId,
                                    ),
                                  ),
                                ),
                                child: SizedBox(
                                  width: 58,
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          UserAvatar(
                                            name: member.name,
                                            imageUrl: member.avatarUrl,
                                            radius: 24,
                                          ),
                                          Positioned(
                                            right: -1,
                                            bottom: -1,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF45B95C),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: scheme.surface,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        member.name.split(' ').first,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (communities.isEmpty) ...[
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
                        ),
                        const SizedBox(height: 16),
                      ],
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
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FeedFiltersHeader(
                    height: 48,
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: FeedFilterBar(
                        key: ValueKey(_selectedCommunityId),
                        labels: [
                          for (final category in categoryNames)
                            context.tr(category),
                        ],
                        selectedIndex: categoryNames.indexOf(_category),
                        onSelected: (index) =>
                            setState(() => _category = categoryNames[index]),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  sliver: SliverList.list(
                    children: [
                      for (final post in filteredPosts) ...[
                        PostCard(
                          key: ValueKey(post.id),
                          collapseText: true,
                          showCommunity: false,
                          onTap: () =>
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostDetailPage(
                                    postId: post.id,
                                    repository: widget.repository,
                                    initialPost: post,
                                    category:
                                        data
                                            .categories[post.categoryId]
                                            ?.name ??
                                        'Post',
                                    icon:
                                        data
                                            .categories[post.categoryId]
                                            ?.icon ??
                                        '💬',
                                    community:
                                        communityById[post.communityId]?.name ??
                                        'Wicchu',
                                  ),
                                ),
                              ).then((_) {
                                if (mounted) setState(_reload);
                              }),
                          category:
                              data.categories[post.categoryId]?.name ?? 'Post',
                          icon: data.categories[post.categoryId]?.icon ?? '💬',
                          community:
                              communityById[post.communityId]?.name ?? 'Wicchu',
                          author: post.authorName,
                          authorAvatarUrl: post.authorAvatarUrl,
                          onAuthorTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberProfilePage(
                                userId: post.authorId,
                                repository: widget.repository,
                              ),
                            ),
                          ),
                          onMentionTap: (userId) => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MemberProfilePage(userId: userId, repository: widget.repository)),
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
                                  if (mounted) setState(_reload);
                                }
                              : null,
                          onDelete: post.ownedByMe
                              ? () async {
                                  await widget.repository.deletePost(post.id);
                                  if (mounted) setState(_reload);
                                }
                              : null,
                          text: post.text,
                          likes: post.reactionCount,
                          comments: post.commentCount,
                          media: post.media,
                          poll: post.poll,
                          onPollVote: (optionId) =>
                              widget.repository.voteOnPost(post.id, optionId),
                          promotion: post.promotion,
                          onPromotionImpression: post.promotion == null
                              ? null
                              : () =>
                                    widget.repository.recordPromotionImpression(
                                      post.promotion!.id,
                                    ),
                          onPromotionClick: post.promotion == null
                              ? null
                              : () => widget.repository.recordPromotionClick(
                                  post.promotion!.id,
                                ),
                          reacted: post.reactedByMe,
                          onReaction: (reacted) => widget.repository
                              .setPostReaction(post.id, reacted: reacted),
                          onComments: () => showPostComments(
                            context,
                            widget.repository,
                            post,
                          ),
                          saved: post.savedByMe,
                          onSaved: (saved) => widget.repository.setPostSaved(
                            post.id,
                            saved: saved,
                          ),
                          onReport: (reason) =>
                              widget.repository.reportPost(post.id, reason),
                          onShare: () => sharePost(
                            widget.repository,
                            post,
                            communityName:
                                communityById[post.communityId]?.name ??
                                'Wicchu',
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeedFiltersHeader extends SliverPersistentHeaderDelegate {
  _FeedFiltersHeader({required this.child, required this.height});
  final Widget child;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant _FeedFiltersHeader oldDelegate) => true;
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
  bool _locating = false;

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
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!(preferences.getBool('location_discovery') ?? true)) {
        _showLocationIssue(
          'Enable nearby discovery in Settings first.',
          actionLabel: 'Settings',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AccountSettingsPage(repository: widget.repository),
            ),
          ),
        );
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationIssue(
          'Enable location services to discover nearby communities.',
          actionLabel: 'Open settings',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationIssue(
          'Location permission is required for nearby discovery.',
          actionLabel: 'Open settings',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _showLocationIssue(
          'Location permission is required for nearby discovery.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final nearby = await widget.repository.listNearbyCommunities(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _usingLocation = true;
        _communities = Future.value(nearby);
      });
    } on TimeoutException {
      _showLocationIssue('Could not get your location. Try again.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationIssue(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(message)),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: context.tr(actionLabel),
                onPressed: onAction,
              ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (_usingLocation) {
      await _findNearby();
      return;
    }
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
            _locating
                ? 'Finding nearby communities…'
                : _usingLocation
                ? 'Show all communities'
                : 'Use my location',
          ),
          onPressed: _locating
              ? null
              : _usingLocation
              ? () => setState(_reload)
              : _findNearby,
          icon: _locating
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_usingLocation ? Icons.location_on : Icons.my_location),
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
            '📍 ${context.tr(_locating
                ? 'Finding nearby communities…'
                : _usingLocation
                ? 'Nearby communities'
                : 'Explore communities')}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (_usingLocation) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 4),
                Expanded(child: Text(context.tr('Using your location'))),
                TextButton(
                  onPressed: () => setState(_reload),
                  child: Text(context.tr('Show all')),
                ),
              ],
            ),
          ],
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
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = PushNotificationService.instance.received
        .listen((_) {
          if (mounted) setState(_reload);
        });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

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
              final icon = switch (notification.type) {
                CommunityNotificationType.postReaction => Icons.favorite_border,
                CommunityNotificationType.postMention => Icons.alternate_email,
                CommunityNotificationType.commentReaction =>
                  Icons.favorite_border,
                CommunityNotificationType.postComment ||
                CommunityNotificationType.commentReply ||
                CommunityNotificationType.commentApproved ||
                CommunityNotificationType.commentRejected ||
                CommunityNotificationType.commentRemoved =>
                  Icons.chat_bubble_outline,
                CommunityNotificationType.membershipRequest =>
                  Icons.person_add_alt_1_outlined,
                CommunityNotificationType.communityInvitation =>
                  Icons.mail_outline,
                CommunityNotificationType.communityRoleChanged =>
                  Icons.admin_panel_settings_outlined,
                CommunityNotificationType.postPending ||
                CommunityNotificationType.commentPending =>
                  Icons.pending_actions_outlined,
                CommunityNotificationType.reportCreated => Icons.flag_outlined,
                CommunityNotificationType.postApproved ||
                CommunityNotificationType.postRestored ||
                CommunityNotificationType.membershipApproved ||
                CommunityNotificationType.memberUnbanned ||
                CommunityNotificationType.promotionApproved =>
                  Icons.check_circle_outline,
                CommunityNotificationType.postRejected ||
                CommunityNotificationType.postRemoved ||
                CommunityNotificationType.membershipRejected ||
                CommunityNotificationType.memberBanned ||
                CommunityNotificationType.promotionRejected =>
                  Icons.error_outline,
              };
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
    if (notification.type == CommunityNotificationType.communityInvitation) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MyCommunityInvitationsPage(repository: widget.repository),
        ),
      );
      if (mounted) setState(_reload);
      return;
    }
    if ({
      CommunityNotificationType.promotionApproved,
      CommunityNotificationType.promotionRejected,
    }.contains(notification.type)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromotionsPage(repository: widget.repository),
        ),
      );
      if (mounted) setState(_reload);
      return;
    }
    final postCanOpen = {
      CommunityNotificationType.postReaction,
      CommunityNotificationType.postMention,
      CommunityNotificationType.commentReaction,
      CommunityNotificationType.postComment,
      CommunityNotificationType.commentReply,
      CommunityNotificationType.postApproved,
      CommunityNotificationType.postRestored,
      CommunityNotificationType.commentApproved,
    }.contains(notification.type);
    if (!postCanOpen || notification.postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Update received'))));
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

  Future<void> _openMyProfile(String userId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemberProfilePage(userId: userId, repository: widget.repository),
      ),
    );
    if (mounted) await _refreshProfile();
  }

  Widget _accountSection(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(
      context.tr(title),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

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
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openMyProfile(profile.id),
                child: Column(
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text('@${profile.userName}'),
                    const SizedBox(height: 8),
                    Text(
                      '${context.trCount(profile.communityCount, singular: '{count} community', plural: '{count} communities')} · '
                      '${context.trCount(profile.postCount, singular: '{count} post', plural: '{count} posts')}',
                    ),
                    TextButton.icon(
                      onPressed: () => _openMyProfile(profile.id),
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: Text(context.tr('View my profile')),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _accountSection('My content'),
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
            icon: Icons.mail_outline,
            label: 'Invitations',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MyCommunityInvitationsPage(repository: widget.repository),
              ),
            ),
          ),
          _ProfileRow(
            icon: Icons.bookmark_border,
            label: 'Saved posts',
            onTap: () =>
                _openPosts('Saved posts', widget.repository.listSavedPosts),
          ),
          _accountSection('Management'),
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
            icon: Icons.campaign_outlined,
            label: 'Promote locally',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PromotionsPage(repository: widget.repository),
              ),
            ),
          ),
          _accountSection('Preferences'),
          _ProfileRow(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AccountSettingsPage(repository: widget.repository),
              ),
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
