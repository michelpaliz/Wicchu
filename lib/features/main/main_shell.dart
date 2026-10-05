import '../../widgets/wicchu_logo.dart';
import '../../widgets/block_visibility_listener.dart';
import '../community/space_role_icon.dart';
import '../community/space_collection_list.dart';
import '../community/category_empty_state.dart';
import '../../widgets/feed_filter_bar.dart';
import '../../widgets/responsive_side_panel.dart';
import 'dart:async';
import 'dart:math' as math;

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
import '../admin/create_community_page.dart';
import '../admin/managed_communities_page.dart';
import '../admin/pending_posts_page.dart';
import '../admin/platform_moderation_page.dart';
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
import '../profile/edit_profile_links.dart';

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
  WicchuProfile? _navigationProfile;
  Community? _navigationSpace;
  final _profilePostRequest = ValueNotifier<int>(0);
  final _homeKey = GlobalKey<_HomeTabState>();
  final _communityPostRequest = ValueNotifier<int>(0);
  int _exploreRevision = 0;
  int _profileRevision = 0;
  int _communitiesRevision = 0;

  @override
  void dispose() {
    _communityPostRequest.dispose();
    _profilePostRequest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        key: _homeKey,
        onExplore: () => _selectDestination(1),
        repository: widget.repository,
        onCommunitiesChanged: () => setState(() {
          _exploreRevision++;
          _communitiesRevision++;
          _profileRevision++;
        }),
      ),
      _ExploreTab(
        key: ValueKey('explore-$_exploreRevision'),
        repository: widget.repository,
        onCommunitiesChanged: () {
          _homeKey.currentState?.refresh();
          setState(() {
            _profileRevision++;
            _communitiesRevision++;
          });
        },
      ),
      if (_index == 2)
        _ActiveCommunityTab(
          key: ValueKey('communities-$_communitiesRevision'),
          repository: widget.repository,
          loadCommunities: _loadMyCommunities,
          postRequest: _communityPostRequest,
          onExplore: () => _selectDestination(1),
          onChanged: () => _homeKey.currentState?.refresh(),
        )
      else
        const SizedBox.shrink(),
      _ProfileTab(
        postRequest: _profilePostRequest,
        onSpaceSelected: (space) => setState(() => _navigationSpace = space),
        repository: widget.repository,
        authGateway: widget.authGateway,
        onSignedOut: widget.onSignedOut,
        refreshVersion: _profileRevision,
        onProfileLoaded: (profile) {
          if (mounted) setState(() => _navigationProfile = profile);
        },
        onBrowsePosts: () => setState(() => _index = 0),
        onCommunityCreated: () {
          _homeKey.currentState?.refresh();
          setState(() => _exploreRevision++);
        },
      ),
    ];
    final content = IndexedStack(index: _index, children: pages);
    void createPost() {
      if (_index == 3 && _navigationSpace != null) {
        _profilePostRequest.value++;
      } else if (_index == 2) {
        _communityPostRequest.value++;
      } else {
        _homeKey.currentState?.startPost();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= webDesktopBreakpoint;
        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                _DesktopNavigation(
                  selectedIndex: _index,
                  profile: _navigationProfile,
                  space: _navigationSpace,
                  onSelected: _openDesktopDestination,
                  onCreatePost: createPost,
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: content,
          bottomNavigationBar: _CompactBottomNavigation(
            selectedIndex: _index,
            profile: _navigationProfile,
            space: _navigationSpace,
            onSelected: _selectDestination,
            onCreatePost: createPost,
          ),
        );
      },
    );
  }

  Future<List<Community>> _loadMyCommunities() async {
    final lists = await Future.wait([
      widget.repository.listJoinedCommunities(),
      widget.repository.listManagedCommunities(),
    ]);
    return {
      for (final community in lists.expand((items) => items))
        community.id: community,
    }.values.toList();
  }

  Future<void> _openDesktopDestination(int value) async {
    if (value < 2) {
      _selectDestination(value);
      return;
    }
    if (value == 2) {
      await openResponsiveSidePanel<void>(
        context,
        width: 760,
        builder: (_) => _ActiveCommunityTab(
          repository: widget.repository,
          loadCommunities: _loadMyCommunities,
          postRequest: _communityPostRequest,
          onExplore: () {
            Navigator.of(context, rootNavigator: true).maybePop();
            _selectDestination(1);
          },
          onChanged: () => _homeKey.currentState?.refresh(),
        ),
      );
      return;
    }
    await openResponsiveSidePanel<void>(
      context,
      width: 760,
      builder: (_) => _ProfileTab(
        postRequest: _profilePostRequest,
        onSpaceSelected: (space) => setState(() => _navigationSpace = space),
        repository: widget.repository,
        authGateway: widget.authGateway,
        onSignedOut: widget.onSignedOut,
        refreshVersion: _profileRevision,
        onProfileLoaded: (profile) {
          if (mounted) setState(() => _navigationProfile = profile);
        },
        onBrowsePosts: () {
          Navigator.of(context, rootNavigator: true).maybePop();
          _selectDestination(0);
        },
        onCommunityCreated: () {
          _homeKey.currentState?.refresh();
          setState(() => _exploreRevision++);
        },
      ),
    );
  }

  void _selectDestination(int value) {
    if (value == 0) _homeKey.currentState?.refresh();
    setState(() {
      _index = value;
      if (value == 2) _communitiesRevision++;
      if (value == 3) _profileRevision++;
    });
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.profile,
    required this.space,
    required this.onSelected,
    required this.onCreatePost,
  });

  final int selectedIndex;
  final WicchuProfile? profile;
  final Community? space;
  final ValueChanged<int> onSelected;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        width: 248,
        child: NavigationRail(
          extended: true,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          minExtendedWidth: 248,
          backgroundColor: scheme.surface,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: WicchuTitle(),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onCreatePost,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.tr('Post')),
                ),
              ],
            ),
          ),
          destinations: [
            NavigationRailDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: Text(context.tr('Home')),
            ),
            NavigationRailDestination(
              icon: const Icon(CupertinoIcons.compass),
              selectedIcon: const Icon(CupertinoIcons.compass_fill),
              label: Text(context.tr('Explore')),
            ),
            NavigationRailDestination(
              icon: const Icon(CupertinoIcons.person_2),
              selectedIcon: const Icon(CupertinoIcons.person_2_fill),
              label: Text(context.tr('Community')),
            ),
            NavigationRailDestination(
              icon: profile == null
                  ? const Icon(CupertinoIcons.person)
                  : UserAvatar(
                      name: space?.name ?? profile!.name,
                      imageUrl: space?.imageUrl ?? profile!.avatarUrl,
                      radius: 13,
                    ),
              selectedIcon: profile == null
                  ? const Icon(CupertinoIcons.person_fill)
                  : UserAvatar(
                      name: space?.name ?? profile!.name,
                      imageUrl: space?.imageUrl ?? profile!.avatarUrl,
                      radius: 13,
                    ),
              label: Text(context.tr('You')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCommunityTab extends StatefulWidget {
  const _ActiveCommunityTab({
    super.key,
    required this.repository,
    required this.loadCommunities,
    required this.postRequest,
    required this.onExplore,
    required this.onChanged,
  });

  final CommunityRepository repository;
  final Future<List<Community>> Function() loadCommunities;
  final VoidCallback onExplore;
  final VoidCallback onChanged;
  final Listenable postRequest;

  @override
  State<_ActiveCommunityTab> createState() => _ActiveCommunityTabState();
}

class _ActiveCommunityTabState extends State<_ActiveCommunityTab> {
  late Future<List<Community>> _data = _load();
  String? _selectedId;
  String? _preferenceKey;

  @override
  void initState() {
    super.initState();
    widget.postRequest.addListener(_handleEmptyPostRequest);
  }

  void _handleEmptyPostRequest() {
    if (_selectedId == null) widget.onExplore();
  }

  @override
  void dispose() {
    widget.postRequest.removeListener(_handleEmptyPostRequest);
    super.dispose();
  }

  Future<List<Community>> _load() async {
    final communities = await widget.loadCommunities();
    final profile = await widget.repository.getProfile();
    final preferences = await SharedPreferences.getInstance();
    _preferenceKey = 'currentCommunityId:${profile.id}';
    final saved = preferences.getString(_preferenceKey!);
    _selectedId = communities.any((c) => c.id == saved)
        ? saved
        : communities.firstOrNull?.id;
    if (_selectedId != null) {
      await preferences.setString(_preferenceKey!, _selectedId!);
    } else {
      await preferences.remove(_preferenceKey!);
    }
    return communities;
  }

  Future<void> _choose(List<Community> communities) async {
    final selected = await showModalBottomSheet<Community>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _CommunitySwitcherHeading(count: communities.length),
            for (final community in communities)
              _CommunitySwitcherRow(
                community: community,
                selected: community.id == _selectedId,
                onTap: () => Navigator.pop(sheetContext, community),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey!, selected.id);
    if (!mounted) return;
    setState(() => _selectedId = selected.id);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Community>>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _LoadError(
          error: snapshot.error!,
          onRetry: () => setState(() => _data = _load()),
        );
      }
      final communities = snapshot.data ?? [];
      final active = communities.where((c) => c.id == _selectedId).firstOrNull;
      if (active == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.tr('Communities'))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.holiday_village_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Find your community'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: widget.onExplore,
                    icon: const Icon(Icons.explore_outlined),
                    label: Text(context.tr('Explore communities')),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return CommunityProfilePage(
        key: ValueKey(active.id),
        community: active,
        repository: widget.repository,
        embedded: true,
        postRequest: widget.postRequest,
        onSwitchCommunity: communities.length > 1
            ? () => _choose(communities)
            : null,
      );
    },
  );
}

class _CompactBottomNavigation extends StatelessWidget {
  const _CompactBottomNavigation({
    required this.selectedIndex,
    this.profile,
    this.space,
    required this.onSelected,
    required this.onCreatePost,
  });

  final int selectedIndex;
  final WicchuProfile? profile;
  final Community? space;
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
                      icon: CupertinoIcons.person_2,
                      selectedIcon: CupertinoIcons.person_2_fill,
                      label: context.tr('Community'),
                      selected: selectedIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                    _CompactNavigationItem(
                      icon: CupertinoIcons.person,
                      selectedIcon: CupertinoIcons.person_fill,
                      customIcon: profile == null
                          ? null
                          : ExcludeSemantics(
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedIndex == 3
                                        ? scheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: UserAvatar(
                                  name: space?.name ?? profile!.name,
                                  imageUrl: space == null
                                      ? profile!.avatarUrl
                                      : space!.imageUrl,
                                  radius: 11,
                                ),
                              ),
                            ),
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
    this.customIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final Widget? customIcon;
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
              customIcon ??
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
    required this.followingPostIds,
  });

  final List<Community> communities;
  final List<CommunityPost> posts;
  final Map<String, CommunityCategory> categories;
  final List<CommunityMember> members;
  final List<CommunityMember> onlineMembers;
  final Set<String> followingPostIds;
}

class _HomeTabState extends State<_HomeTab>
    with BlockVisibilityListener<_HomeTab> {
  @override
  CommunityRepository get visibilityRepository => widget.repository;
  @override
  void reloadBlockVisibility() {
    setState(_reload);
  }

  bool _followingOnly = false;
  late Future<_HomeFeedData> _data;
  late Future<NotificationFeed> _notifications;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  void _reloadNotifications() {
    _notifications = widget.repository.listNotifications();
  }

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
    _reloadNotifications();
    _notificationSubscription = PushNotificationService.instance.received
        .listen((_) {
          if (mounted) setState(_reloadNotifications);
        });
    _reload();
  }

  void _reload() {
    _data = _loadData();
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _notificationSubscription?.cancel();
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
      (community) => widget.repository
          .listMembers(community.id)
          .catchError((_) => <CommunityMember>[]),
    );
    final results = await Future.wait([
      widget.repository
          .listFollowingPosts(query: _query)
          .catchError((_) => <CommunityPost>[]),
      ...communities.map(
        (community) => widget.repository
            .listCategories(community.id)
            .catchError((_) => <CommunityCategory>[]),
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
    final posts = results.first.cast<CommunityPost>().toList();
    final followingPostIds = posts.map((post) => post.id).toSet();
    // Discovery stays local and public. A failed optional discovery request
    // must never prevent the followed feed from loading.
    final sources = {
      for (final community in communities) community.id: community,
    };
    try {
      final townIds = communities.map((c) => c.town.id).toSet();
      final nearby = (await widget.repository.listCommunities())
          .where(
            (c) =>
                c.visibility == CommunityVisibility.public &&
                !sources.containsKey(c.id) &&
                townIds.contains(c.town.id),
          )
          .take(3);
      await Future.wait(
        nearby.map((community) async {
          try {
            final localPosts = await widget.repository.listPosts(
              community.id,
              query: _query,
            );
            sources[community.id] = community;
            posts.addAll(localPosts.take(5));
          } catch (_) {
            // The server remains responsible for access and blocking rules.
          }
        }),
      );
    } catch (_) {}
    for (final id in posts.map((post) => post.communityId).toSet()) {
      if (!sources.containsKey(id)) {
        try {
          sources[id] = await widget.repository.getCommunity(id);
        } catch (_) {}
      }
    }

    final categories = <String, CommunityCategory>{};
    for (final result in results.skip(1)) {
      for (final category in result.cast<CommunityCategory>()) {
        categories[category.id] = category;
      }
    }
    await Future.wait(
      sources.keys.where((id) => !communities.any((c) => c.id == id)).map((
        id,
      ) async {
        try {
          for (final category in await widget.repository.listCategories(id)) {
            categories[category.id] = category;
          }
        } catch (_) {}
      }),
    );
    final uniquePosts = {
      for (final post in posts) post.id: post,
    }.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _HomeFeedData(
      communities: sources.values.toList(),
      posts: uniquePosts,
      followingPostIds: followingPostIds,
      categories: categories,
      members: membersByUserId.values.toList(growable: false),
      onlineMembers: onlineByUserId.values.toList(growable: false),
    );
  }

  void refresh() {
    if (mounted) {
      setState(() {
        _selectedCommunityId = null;
        _reload();
        _reloadNotifications();
      });
    }
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
      if (active != null && active.canPublish) {
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
    if (!community.canPublish) return;
    try {
      final categories = await widget.repository.listCategories(community.id);
      if (!mounted) return;
      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('No categories found'))),
        );
        return;
      }
      final post = await openPostComposer(
        context,
        community: community,
        repository: widget.repository,
        categories: categories,
        initialCategory: categories
            .where((category) => category.name == _category)
            .firstOrNull,
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
    communities = communities.where((space) => space.canPublish).toList();
    if (communities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('No spaces available for publishing.')),
        ),
      );
      return;
    }
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
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .55,
        minChildSize: .35,
        maxChildSize: .95,
        expand: false,
        snap: true,
        snapSizes: const [.55],
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _CommunitySwitcherHeading(count: communities.length),
              for (final community in communities)
                _CommunitySwitcherRow(
                  community: community,
                  selected: community.id == _selectedCommunityId,
                  onTap: () => Navigator.pop(sheetContext, community.id),
                ),
              Divider(
                height: 24,
                indent: 20,
                endIndent: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .08),
              ),
              _CommunitySwitcherAction(
                icon: Icons.explore_outlined,
                title: context.tr('Explore spaces'),
                subtitle: context.tr('Discover new communities and profiles'),
                onTap: () => Navigator.pop(sheetContext, '__explore'),
              ),
              _CommunitySwitcherAction(
                icon: Icons.add,
                title: context.tr('Create a community or profile'),
                subtitle: context.tr(
                  'Bring people together or share your updates',
                ),
                onTap: () => Navigator.pop(sheetContext, '__create'),
              ),
              const SizedBox(height: 12),
            ],
          ),
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
                    openResponsiveSidePanel<void>(
                      context,
                      builder: (_) => MemberProfilePage(
                        repository: widget.repository,
                        userId: member.userId,
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
        title: const WicchuTitle(),
        actions: [
          IconButton(
            tooltip: context.tr('My spaces'),
            icon: const Icon(Icons.groups_outlined),
            onPressed: () async {
              final data = await _data;
              if (mounted) {
                await _chooseCommunity(
                  data.communities.where((c) => c.myRole != null).toList(),
                );
              }
            },
          ),
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
          FutureBuilder<NotificationFeed>(
            future: _notifications,
            builder: (context, snapshot) {
              final unread = snapshot.data?.unreadCount ?? 0;
              return IconButton(
                tooltip: context.tr('Notifications'),
                icon: Badge.count(
                  count: unread,
                  isLabelVisible: unread > 0,
                  child: const Icon(CupertinoIcons.bell),
                ),
                onPressed: () async {
                  await openResponsiveSidePanel<void>(
                    context,
                    width: 620,
                    builder: (_) => _ActivityTab(repository: widget.repository),
                  );
                  if (mounted) setState(_reloadNotifications);
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
          if (communities.isEmpty && data.posts.isEmpty) {
            return _homeOnboarding(communities);
          }
          final visibleCommunities = communities;
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
            final matchesTown =
                !_followingOnly || data.followingPostIds.contains(post.id);
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

          final windowWidth = MediaQuery.sizeOf(context).width;
          final viewportWidth = math.min(
            windowWidth >= 800 ? windowWidth - 249 : windowWidth,
            1240,
          );
          final horizontalGutter = math.max(0.0, (viewportWidth - 860) / 2);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalGutter),
            child: RefreshIndicator(
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
                                MediaQuery.textScalerOf(context).scale(12) *
                                    1.5,
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
                                                color:
                                                    scheme.onPrimaryContainer,
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
                                  onTap: () => openResponsiveSidePanel<void>(
                                    context,
                                    builder: (_) => MemberProfilePage(
                                      repository: widget.repository,
                                      userId: member.userId,
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
                                                  color: const Color(
                                                    0xFF45B95C,
                                                  ),
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
                      height: 44,
                      child: ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: FeedFilterBar(
                          height: 44,
                          labels: [
                            context.tr('For you'),
                            context.tr('Following'),
                          ],
                          selectedIndex: _followingOnly ? 1 : 0,
                          onSelected: (index) => setState(() {
                            _followingOnly = index == 1;
                            _category = 'All';
                          }),
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
                            repository: widget.repository,
                            post: post,
                            key: ValueKey(post.id),
                            collapseText: true,
                            showCommunity: true,
                            communityFirst: !_followingOnly,
                            onCommunityTap:
                                communityById[post.communityId] == null
                                ? null
                                : () => openResponsiveSidePanel<void>(
                                    context,
                                    builder: (_) => CommunityProfilePage(
                                      community:
                                          communityById[post.communityId]!,
                                      repository: widget.repository,
                                    ),
                                  ),
                            onTap: () =>
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostCollectionPage(
                                      title: _followingOnly
                                          ? 'Following'
                                          : 'For you',
                                      initialPostId: post.id,
                                      initialPosts: filteredPosts,
                                      repository: widget.repository,
                                      loadPosts: () async {
                                        final refreshed = await _loadData();
                                        final ids = filteredPosts
                                            .map((p) => p.id)
                                            .toSet();
                                        return refreshed.posts
                                            .where((p) => ids.contains(p.id))
                                            .toList();
                                      },
                                      categories: data.categories,
                                      communityNames: {
                                        for (final c in data.communities)
                                          c.id: c.name,
                                      },
                                    ),
                                  ),
                                ).then((_) {
                                  if (mounted) setState(_reload);
                                }),
                            category:
                                data.categories[post.categoryId]?.name ??
                                'Post',
                            icon:
                                data.categories[post.categoryId]?.icon ?? '💬',
                            community:
                                communityById[post.communityId]?.name ??
                                'Wicchu',
                            author: post.authorName,
                            authorAvatarUrl: post.authorAvatarUrl,
                            isAnonymousAuthor: post.isAnonymous,
                            onAuthorTap: () => openResponsiveSidePanel<void>(
                              context,
                              builder: (_) => MemberProfilePage(
                                userId: post.authorId,
                                repository: widget.repository,
                              ),
                            ),
                            onMentionTap: (userId) =>
                                openResponsiveSidePanel<void>(
                                  context,
                                  builder: (_) => MemberProfilePage(
                                    userId: userId,
                                    repository: widget.repository,
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
                                : () => widget.repository
                                      .recordPromotionImpression(
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
                            onReport: (reason, category, {hidePost}) =>
                                widget.repository.reportPost(
                                  post.id,
                                  reason,
                                  category: category,
                                  hidePost: hidePost == true,
                                ),
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
                        if (filteredPosts.isEmpty &&
                            _category != 'All' &&
                            normalizedQuery.isEmpty)
                          CategoryEmptyState(
                            category: _category,
                            onPublish: startPost,
                          )
                        else if (filteredPosts.isEmpty)
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
                                    context.tr(
                                      'Try another search or category.',
                                    ),
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
  final _searchController = TextEditingController();
  String _query = '';
  int _filter = 0;
  int _createdWithinDays = 0;
  int _audienceRange = 0;
  Position? _position;
  bool _usingLocation = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (_filter == 2) {
      _communities = widget.repository.listJoinedCommunities();
    } else if (_filter == 1) {
      final position = _position;
      _communities = position == null
          ? Future.value([])
          : widget.repository.listNearbyCommunities(
              latitude: position.latitude,
              longitude: position.longitude,
            );
    } else {
      _communities = widget.repository.listCommunities(query: _query);
    }
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
        _position = position;
        if (_filter == 1) _communities = Future.value(nearby);
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
    if (_filter == 1) {
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
    _searchController.dispose();
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

  void _selectFilter(int index) {
    _searchDelay?.cancel();
    setState(() {
      _query = _searchController.text;
      _filter = index;
      _reload();
    });
    if (index == 1 && !_usingLocation) _findNearby();
  }

  Future<void> _createCommunity() async {
    final created = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(repository: widget.repository),
      ),
    );
    if (created == null || !mounted) return;
    setState(_reload);
    widget.onCommunitiesChanged();
    await _openCommunity(created);
  }

  Future<void> _openCommunity(Community community) async {
    await openResponsiveSidePanel<void>(
      context,
      builder: (_) => CommunityProfilePage(
        community: community,
        repository: widget.repository,
      ),
    );
    if (!mounted) return;
    setState(_reload);
    widget.onCommunitiesChanged();
  }

  Widget _emptyState() {
    final searching = _query.trim().isNotEmpty;
    final title = searching
        ? 'No communities found'
        : _filter == 1
        ? 'No communities nearby yet'
        : _filter == 2
        ? 'Find your community'
        : 'No communities to explore yet';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 150,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .5),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 76,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .6),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.search_rounded,
                    size: 68,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr(title),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              searching
                  ? 'Try another name or location.'
                  : _filter == 2
                  ? 'Discover communities nearby and connect with your neighbors.'
                  : 'Be the first to create a community and connect with people in your area.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (!searching)
            FilledButton.icon(
              onPressed: _filter == 2
                  ? () => _selectFilter(0)
                  : _createCommunity,
              icon: Icon(_filter == 2 ? Icons.explore_outlined : Icons.add),
              label: Text(
                context.tr(
                  _filter == 2 ? 'Explore communities' : 'Create community',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _communityCard(Community community) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final typeIcon = !community.isPublicProfile
        ? Icons.groups_outlined
        : community.profileCategory == ProfileCategory.localBusiness
        ? Icons.storefront_outlined
        : Icons.person_outline;
    Widget metadata(
      IconData icon,
      String text, {
      CommunityVisibility? visibility,
    }) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (visibility != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: context.tr(
              visibility == CommunityVisibility.public ? 'Public' : 'Private',
            ),
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              visibility == CommunityVisibility.public
                  ? Icons.public
                  : Icons.lock_outline,
              size: 15,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.tr(
                visibility == CommunityVisibility.public ? 'Public' : 'Private',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: .07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCommunity(community),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final action = community.isJoined
                  ? SpaceRoleIcon(space: community)
                  : FilledButton(
                      onPressed: _saving.contains(community.id)
                          ? null
                          : () => _toggleMembership(community),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: _saving.contains(community.id)
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.tr(
                                community.isPublicProfile ? 'Follow' : 'Join',
                              ),
                            ),
                    );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: compact ? 48 : 56,
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CommunityAvatar(
                              community: community,
                              radius: compact ? 24 : 28,
                            ),
                            Positioned(
                              left: -4,
                              top: -2,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: scheme.surface,
                                child: Icon(
                                  typeIcon,
                                  size: 15,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                community.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 16,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!compact && !community.isJoined) ...[
                              const SizedBox(width: 8),
                              action,
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            metadata(
                              Icons.location_on_outlined,
                              _filter == 1 && community.distanceKm != null
                                  ? '${community.distanceKm!.toStringAsFixed(1).replaceAll('.', context.isSpanish ? ',' : '.')} km'
                                  : community.town.name,
                            ),
                            metadata(
                              Icons.people_outline,
                              context.trCount(
                                community.memberCount,
                                singular: community.isPublicProfile
                                    ? '{count} follower'
                                    : '{count} member',
                                plural: community.isPublicProfile
                                    ? '{count} followers'
                                    : '{count} members',
                              ),
                              visibility: community.isPublicProfile
                                  ? null
                                  : community.visibility,
                            ),
                          ],
                        ),
                        if (!community.isJoined && compact) ...[
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [action],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (community.isJoined) SpaceRoleIcon(space: community),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _discoveryPrompt() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            _searchDelay?.cancel();
            setState(() {
              _searchController.clear();
              _query = '';
              _filter = 0;
              _reload();
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primary.withValues(alpha: .08),
                  child: Icon(
                    Icons.explore_outlined,
                    size: 28,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Not finding what you need?'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Explore more profiles, businesses and communities.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDiscoveryFilters() async {
    var scope = _filter;
    var days = _createdWithinDays;
    var audience = _audienceRange;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('Discovery filters'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: scope,
                  decoration: InputDecoration(labelText: context.tr('Show')),
                  items: [
                    for (final entry in const {
                      0: 'All',
                      3: 'Communities',
                      5: 'Businesses',
                      6: 'People',
                      1: 'Near you',
                      2: 'My communities',
                      4: 'Public profiles',
                    }.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(context.tr(entry.value)),
                      ),
                  ],
                  onChanged: (value) => scope = value ?? 0,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: days,
                  decoration: InputDecoration(labelText: context.tr('Created')),
                  items: [
                    for (final entry in const {
                      0: 'Any time',
                      1: 'Last 24 hours',
                      7: 'Last 7 days',
                      30: 'Last 30 days',
                      90: 'Last 90 days',
                    }.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(context.tr(entry.value)),
                      ),
                  ],
                  onChanged: (value) => days = value ?? 0,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: audience,
                  decoration: InputDecoration(
                    labelText: context.tr('Members / followers'),
                  ),
                  items: [
                    for (final entry in const {
                      0: 'Any number',
                      1: 'Fewer than 50',
                      2: '50–499',
                      3: '500 or more',
                    }.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(context.tr(entry.value)),
                      ),
                  ],
                  onChanged: (value) => audience = value ?? 0,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(context.tr('Apply filters')),
                ),
                TextButton(
                  onPressed: () {
                    scope = 0;
                    days = 0;
                    audience = 0;
                    Navigator.pop(sheetContext, true);
                  },
                  child: Text(context.tr('Reset filters')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || apply != true) return;
    setState(() {
      _createdWithinDays = days;
      _audienceRange = audience;
    });
    _selectFilter(scope);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 16,
      title: TextField(
        key: const ValueKey('explore-search'),
        controller: _searchController,
        onChanged: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.tr('Search communities, businesses or people…'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: context.tr('Clear search'),
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchDelay?.cancel();
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _reload();
                      });
                    },
                  ),
          ),
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('Discovery filters'),
          onPressed: _openDiscoveryFilters,
          icon: Badge(
            isLabelVisible: _createdWithinDays != 0 || _audienceRange != 0,
            child: Icon(
              Icons.tune,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Column(
      children: [
        FeedFilterBar(
          height: 48,
          labels: [
            context.tr('All'),
            context.tr('Communities'),
            context.tr('Businesses'),
            context.tr('People'),
            if (_filter == 1) context.tr('Near you'),
            if (_filter == 2) context.tr('My communities'),
            if (_filter == 4) context.tr('Public profiles'),
          ],
          selectedIndex: [
            0,
            3,
            5,
            6,
            if ([1, 2, 4].contains(_filter)) _filter,
          ].indexOf(_filter),
          onSelected: (index) => _selectFilter(
            [
              0,
              3,
              5,
              6,
              if ([1, 2, 4].contains(_filter)) _filter,
            ][index],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Community>>(
              future: _communities,
              builder: (context, snapshot) {
                Widget? status;
                if (_filter == 1 && !_usingLocation) {
                  status = Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        if (_locating)
                          const CircularProgressIndicator()
                        else
                          const Icon(Icons.location_on_outlined, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            _locating
                                ? 'Finding nearby communities…'
                                : 'Use your location to find nearby communities.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (!_locating)
                          TextButton(
                            onPressed: _findNearby,
                            child: Text(context.tr('Use my location')),
                          ),
                      ],
                    ),
                  );
                } else if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  status = const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  status = _LoadError(
                    error: snapshot.error!,
                    onRetry: _refresh,
                  );
                }
                final query = _query.trim().toLowerCase();
                final cutoff = _createdWithinDays == 0
                    ? null
                    : DateTime.now().subtract(
                        Duration(days: _createdWithinDays),
                      );
                final communities = (snapshot.data ?? <Community>[])
                    .where(
                      (community) => _filter == 3
                          ? !community.isPublicProfile
                          : _filter == 5
                          ? community.isPublicProfile &&
                                community.profileCategory ==
                                    ProfileCategory.localBusiness
                          : _filter == 6
                          ? community.isPublicProfile &&
                                (community.profileCategory ==
                                        ProfileCategory.person ||
                                    community.profileCategory ==
                                        ProfileCategory.creator)
                          : _filter == 4
                          ? community.isPublicProfile
                          : true,
                    )
                    .where(
                      (community) =>
                          query.isEmpty ||
                          community.name.toLowerCase().contains(query) ||
                          community.town.name.toLowerCase().contains(query),
                    )
                    .where(
                      (community) =>
                          (cutoff == null ||
                              !community.createdAt.isBefore(cutoff)) &&
                          switch (_audienceRange) {
                            1 => community.memberCount < 50,
                            2 =>
                              community.memberCount >= 50 &&
                                  community.memberCount < 500,
                            3 => community.memberCount >= 500,
                            _ => true,
                          },
                    )
                    .toList();
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (status != null)
                      status
                    else if (communities.isEmpty &&
                        (_createdWithinDays != 0 || _audienceRange != 0))
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              context.tr('No spaces match these filters.'),
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: _openDiscoveryFilters,
                              child: Text(context.tr('Adjust filters')),
                            ),
                          ],
                        ),
                      )
                    else if (communities.isEmpty)
                      _emptyState()
                    else
                      ...communities.map(_communityCard),
                    if (status == null &&
                        communities.isNotEmpty &&
                        (_filter != 0 || query.isNotEmpty))
                      _discoveryPrompt(),
                  ],
                );
              },
            ),
          ),
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
  const _ActivityTab({required this.repository});

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

  bool _unreadOnly = false;
  bool _markingAll = false;
  String? _openingReviewId;

  String _dateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = date.toLocal();
    if (!local.isBefore(today)) return 'Today';
    if (!local.isBefore(DateTime(now.year, now.month, now.day - 1))) {
      return 'Yesterday';
    }
    if (!local.isBefore(today.subtract(Duration(days: today.weekday - 1)))) {
      return 'This week';
    }
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Notifications'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('Notification settings'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AccountSettingsPage(repository: widget.repository),
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Row(
                    children: [
                      for (final unread in [false, true]) ...[
                        if (unread) const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .14),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .04),
                            labelStyle: TextStyle(
                              color: _unreadOnly == unread
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                context.tr(
                                  unread ? 'Unread' : 'All notifications',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            selected: _unreadOnly == unread,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _unreadOnly = unread),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<NotificationFeed>(
                future: _feed,
                builder: (context, snapshot) => SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    key: const ValueKey('mark-all-notifications-read'),
                    style: TextButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .06),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed:
                        !_markingAll &&
                            snapshot.connectionState == ConnectionState.done &&
                            !snapshot.hasError &&
                            (snapshot.data?.unreadCount ?? 0) > 0
                        ? _markAllRead
                        : null,
                    icon: _markingAll
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all, size: 22),
                    label: Text(
                      context.tr('Mark all read'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<NotificationFeed>(
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
              final notifications =
                  (snapshot.data?.items ?? const <CommunityNotification>[])
                      .where((item) => !_unreadOnly || !item.isRead)
                      .toList()
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (notifications.isEmpty) {
                return LayoutBuilder(
                  builder: (context, constraints) => RefreshIndicator(
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ExcludeSemantics(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 136,
                                      height: 136,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.08),
                                      ),
                                      child: Icon(
                                        Icons.notifications_none_rounded,
                                        size: 76,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 6,
                                      child: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 42,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                context.tr('You’re all caught up'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.tr('You have no new notifications.'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr(
                                  'We’ll let you know when there is relevant activity.',
                                ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final group = _dateGroup(notification.createdAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0 ||
                            group !=
                                _dateGroup(notifications[index - 1].createdAt))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Text(
                              context.tr(group),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        _notificationRow(notification),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _notificationRow(CommunityNotification notification) {
    final icon = switch (notification.type) {
      CommunityNotificationType.postReaction => Icons.favorite_border,
      CommunityNotificationType.postMention => Icons.alternate_email,
      CommunityNotificationType.commentReaction => Icons.favorite_border,
      CommunityNotificationType.postComment ||
      CommunityNotificationType.commentReply ||
      CommunityNotificationType.commentApproved ||
      CommunityNotificationType.commentRejected ||
      CommunityNotificationType.commentRemoved => Icons.chat_bubble_outline,
      CommunityNotificationType.membershipRequest =>
        Icons.person_add_alt_1_outlined,
      CommunityNotificationType.communityInvitation => Icons.mail_outline,
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
      CommunityNotificationType.promotionApproved => Icons.check_circle_outline,
      CommunityNotificationType.postRejected ||
      CommunityNotificationType.postRemoved ||
      CommunityNotificationType.membershipRejected ||
      CommunityNotificationType.memberRemoved ||
      CommunityNotificationType.memberBanned ||
      CommunityNotificationType.promotionRejected => Icons.error_outline,
    };
    final colors = Theme.of(context).colorScheme;
    final badgeColor = switch (notification.type) {
      CommunityNotificationType.postReaction ||
      CommunityNotificationType.commentReaction => Colors.pink.shade600,
      CommunityNotificationType.postComment ||
      CommunityNotificationType.commentReply => Colors.blue.shade600,
      _ => colors.primary,
    };
    return Card(
      key: ValueKey('notification-${notification.id}'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      color: notification.isRead
          ? colors.surface
          : colors.primary.withValues(alpha: 0.07),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        titleAlignment: ListTileTitleAlignment.top,
        horizontalTitleGap: 16,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              name: notification.actorName,
              imageUrl: notification.actorAvatarUrl,
              radius: 24,
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: Icon(icon, size: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${notification.actorName} ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: context.trNotification(notification.message)),
            ],
          ),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            formatPostTime(context, notification.createdAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        trailing: _openingReviewId == notification.id
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : notification.isRead
            ? Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.onSurfaceVariant,
              )
            : Semantics(
                label: context.tr('Unread'),
                child: Icon(Icons.circle, size: 8, color: colors.primary),
              ),
        onTap: () => _openNotification(notification),
      ),
    );
  }

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

  Future<void> _openPostReview(CommunityNotification notification) async {
    if (_openingReviewId != null) return;
    setState(() => _openingReviewId = notification.id);
    try {
      var communityId = notification.communityId;
      if (communityId.isEmpty && notification.postId.isNotEmpty) {
        communityId = (await widget.repository.getPost(
          notification.postId,
        )).communityId;
      }
      if (communityId.isEmpty) {
        throw StateError('This notification has no community');
      }
      final community = await widget.repository.getCommunity(communityId);
      if (!mounted) return;
      if (!notification.isRead) await _markRead(notification.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PendingPostsPage(
            community: community,
            repository: widget.repository,
          ),
        ),
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _openingReviewId = null);
    }
  }

  Future<void> _openNotification(CommunityNotification notification) async {
    if (notification.type == CommunityNotificationType.postPending) {
      await _openPostReview(notification);
      return;
    }
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
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await widget.repository.markAllNotificationsRead();
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    this.accountHub = false,
    this.onSpaceSelected,
    this.postRequest,
    required this.repository,
    required this.authGateway,
    required this.onSignedOut,
    required this.onCommunityCreated,
    required this.refreshVersion,
    required this.onProfileLoaded,
    required this.onBrowsePosts,
  });
  final bool accountHub;
  final ValueChanged<Community?>? onSpaceSelected;
  final Listenable? postRequest;
  final CommunityRepository repository;
  final AuthGateway authGateway;
  final VoidCallback onSignedOut;
  final VoidCallback onCommunityCreated;
  final int refreshVersion;
  final ValueChanged<WicchuProfile> onProfileLoaded;
  final VoidCallback onBrowsePosts;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Community? _selectedSpace;
  bool _signingOut = false;
  late Future<WicchuProfile> _profile = _loadProfile();

  Future<WicchuProfile> _loadProfile() async {
    final profile = await widget.repository.getProfile();
    if (mounted) widget.onProfileLoaded(profile);
    return profile;
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profile = _loadProfile();
    });
    try {
      await _profile;
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _profile = _loadProfile();
    }
  }

  Future<void> _openMyProfile(String userId) async {
    await openResponsiveSidePanel<void>(
      context,
      builder: (_) =>
          MemberProfilePage(userId: userId, repository: widget.repository),
    );
    if (mounted) await _refreshProfile();
  }

  Widget _accountSection(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      context.tr(title),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  void _openAccountMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfileTab(
          accountHub: true,
          repository: widget.repository,
          authGateway: widget.authGateway,
          onSignedOut: widget.onSignedOut,
          onCommunityCreated: widget.onCommunityCreated,
          refreshVersion: widget.refreshVersion,
          onProfileLoaded: widget.onProfileLoaded,
          onBrowsePosts: () {
            Navigator.pop(context);
            widget.onBrowsePosts();
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _profile = _loadProfile();
        });
      }
    });
  }

  Future<void> _switchProfile(WicchuProfile profile) async {
    try {
      final managed = (await widget.repository.listManagedCommunities())
          .where(
            (c) =>
                c.isPublicProfile &&
                (c.myRole == CommunityRole.owner ||
                    c.myRole == CommunityRole.admin),
          )
          .toList();
      if (!mounted) return;
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: UserAvatar(
                  name: profile.name,
                  imageUrl: profile.avatarUrl,
                  radius: 20,
                ),
                title: Text(profile.name),
                subtitle: Text(context.tr('Personal profile')),
                selected: _selectedSpace == null,
                onTap: () => Navigator.pop(context, 'personal'),
              ),
              for (final space in managed)
                ListTile(
                  leading: UserAvatar(
                    name: space.name,
                    imageUrl: space.imageUrl,
                    radius: 20,
                  ),
                  title: Text(space.name),
                  subtitle: Text(
                    context.tr(
                      space.myRole == CommunityRole.owner
                          ? 'Owner'
                          : 'Administrator',
                    ),
                  ),
                  selected: _selectedSpace?.id == space.id,
                  onTap: () => Navigator.pop(context, space.id),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.tr('Create a public profile')),
                onTap: () => Navigator.pop(context, 'create'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'create') {
        final created = await Navigator.push<Community>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateCommunityPage(
              repository: widget.repository,
              initialType: CommunityType.publicProfile,
            ),
          ),
        );
        if (!mounted || created == null) return;
        setState(() => _selectedSpace = created);
        widget.onSpaceSelected?.call(created);
        widget.onCommunityCreated();
        return;
      }
      final selected = choice == 'personal'
          ? null
          : managed.firstWhere((c) => c.id == choice);
      setState(() => _selectedSpace = selected);
      widget.onSpaceSelected?.call(selected);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accountHub) return _accountHub(context);
    return FutureBuilder<WicchuProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: _LoadError(
              error: snapshot.error!,
              onRetry: () => setState(() {
                _profile = _loadProfile();
              }),
            ),
          );
        }
        final profile = snapshot.data;
        if (profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final space = _selectedSpace;
        if (space != null) {
          return CommunityProfilePage(
            key: ValueKey(space.id),
            community: space,
            repository: widget.repository,
            embedded: true,
            postRequest: widget.postRequest,
            onSwitchCommunity: () => _switchProfile(profile),
            onAccountMenu: _openAccountMenu,
          );
        }
        return MemberProfilePage(
          key: ValueKey(profile.id),
          userId: profile.id,
          repository: widget.repository,
          embedded: true,
          onAccountMenu: _openAccountMenu,
          header: InkWell(
            onTap: () => _switchProfile(profile),
            child: Tooltip(
              message: context.tr('Switch profile'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _accountHub(BuildContext context) => Scaffold(
    backgroundColor: Color.alphaBlend(
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.025),
      Theme.of(context).colorScheme.surface,
    ),
    appBar: AppBar(
      title: Text(context.tr('You')),
      actions: [
        IconButton(
          tooltip: context.tr('Settings'),
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                      _profile = _loadProfile();
                    }),
                  );
                }
                final profile = snapshot.data!;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      button: true,
                      label: context.tr('View profile'),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _openMyProfile(profile.id),
                        child: UserAvatar(
                          name: profile.name,
                          imageUrl: profile.avatarUrl,
                          radius: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '@${profile.userName}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${context.trCount(profile.communityCount, singular: '{count} space', plural: '{count} spaces')} · '
                            '${context.trCount(profile.postCount, singular: '{count} post', plural: '{count} posts')}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.10),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _openMyProfile(profile.id),
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: Text(context.tr('View my profile')),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            _accountSection('My content'),
            _accountCard([
              _ProfileRow(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: () async {
                  await editProfileLinks(context, widget.repository);
                  if (mounted) await _refreshProfile();
                },
              ),
              _ProfileRow(
                icon: Icons.groups_outlined,
                label: 'My spaces',
                onTap: () => _openCommunities(
                  'My spaces',
                  widget.repository.listJoinedCommunities,
                ),
              ),
              _ProfileRow(
                icon: Icons.article_outlined,
                label: 'My posts',
                onTap: () =>
                    _openPosts('My posts', widget.repository.listMyPosts),
              ),
              _ProfileRow(
                icon: Icons.mail_outline,
                label: 'Invitations',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyCommunityInvitationsPage(
                      repository: widget.repository,
                    ),
                  ),
                ),
              ),
              _ProfileRow(
                icon: Icons.bookmark_border,
                label: 'Saved posts',
                onTap: () =>
                    _openPosts('Saved posts', widget.repository.listSavedPosts),
              ),
            ]),
            _accountSection('Management'),
            _accountCard([
              FutureBuilder<WicchuProfile>(
                future: _profile,
                builder: (context, snapshot) =>
                    snapshot.data?.platformModerator == true
                    ? _ProfileRow(
                        icon: Icons.health_and_safety_outlined,
                        label: 'Wicchu Safety',
                        subtitle: 'Platform moderation',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlatformModerationPage(
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              _ProfileRow(
                icon: Icons.shield_outlined,
                label: 'Spaces I manage',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManagedCommunitiesPage(
                        repository: widget.repository,
                        onCommunityCreated: widget.onCommunityCreated,
                      ),
                    ),
                  );
                  if (mounted) await _refreshProfile();
                },
              ),
              _ProfileRow(
                icon: Icons.add_circle_outline,
                label: 'Create a community',
                subtitle: 'For neighborhoods and local groups',
                onTap: () => _createCommunity(),
              ),
              _ProfileRow(
                icon: Icons.person_add_outlined,
                label: 'Create a public profile',
                subtitle: 'For businesses, creators, clubs, and organizations',
                onTap: () => _createCommunity(CommunityType.publicProfile),
              ),
              _ProfileRow(
                icon: Icons.campaign_outlined,
                label: 'Promote locally',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PromotionsPage(repository: widget.repository),
                  ),
                ),
              ),
            ]),
            _accountSection('Account and app'),
            _accountCard([
              _ProfileRow(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountSettingsPage(
                      repository: widget.repository,
                      authGateway: widget.authGateway,
                      onAccountDeleted: widget.onSignedOut,
                    ),
                  ),
                ),
              ),
              _ProfileRow(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => openResponsiveSidePanel<void>(
                  context,
                  width: 620,
                  builder: (_) => _ActivityTab(repository: widget.repository),
                ),
              ),
              _ProfileRow(
                icon: Icons.help_outline,
                label: 'Help',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpPage()),
                ),
              ),
            ]),
            _accountSection('Preferences'),
            _accountCard([
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
            ]),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _signingOut
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              title: Text(context.tr(_signingOut ? 'Signing out…' : 'Log out')),
              enabled: !_signingOut,
              onTap: _signingOut ? null : _logout,
            ),
          ],
        ),
      ),
    ),
  );

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountSettingsPage(
          repository: widget.repository,
          authGateway: widget.authGateway,
          onAccountDeleted: widget.onSignedOut,
        ),
      ),
    );
  }

  Widget _accountCard(List<Widget> children) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: children[i],
          ),
          if (i < children.length - 1)
            Divider(
              height: 1,
              indent: 58,
              endIndent: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.07),
            ),
        ],
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
          onBrowsePosts: title == 'Saved posts'
              ? () {
                  Navigator.pop(context);
                  widget.onBrowsePosts();
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _createCommunity([
    CommunityType type = CommunityType.community,
  ]) async {
    final community = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(
          repository: widget.repository,
          initialType: type,
        ),
      ),
    );
    if (!mounted || community == null) return;
    setState(() {
      _profile = _loadProfile();
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
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.authGateway.signOut();
      if (mounted) widget.onSignedOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
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

  Future<void> _open(Community community) async {
    await openResponsiveSidePanel<void>(
      context,
      builder: (_) => CommunityProfilePage(
        community: community,
        repository: widget.repository,
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _create() async {
    final community = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(repository: widget.repository),
      ),
    );
    if (!mounted || community == null) return;
    await _refresh();
    if (mounted) await _open(community);
  }

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
    appBar: AppBar(
      centerTitle: false,
      title: Text(context.tr(widget.title)),
      actions: [
        TextButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add, size: 20),
          label: Text(context.tr('Create')),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: FutureBuilder<List<Community>>(
      future: _communities,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(error: snapshot.error!, onRetry: _refresh);
        }
        return SpaceCollectionList(
          spaces: snapshot.data ?? const [],
          onOpen: _open,
          onRefresh: _refresh,
        );
      },
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });
  final String? subtitle;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 48,
    visualDensity: const VisualDensity(vertical: -1),
    leading: Icon(icon),
    title: Text(context.tr(label)),
    subtitle: subtitle == null ? null : Text(context.tr(subtitle!)),
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

class _CommunitySwitcherHeading extends StatelessWidget {
  const _CommunitySwitcherHeading({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  context.tr('Your spaces'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Switch between your communities and profiles.'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CommunitySwitcherRow extends StatelessWidget {
  const _CommunitySwitcherRow({
    required this.community,
    required this.selected,
    required this.onTap,
  });
  final Community community;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          selected: selected,
          selectedColor: colors.onSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          leading: CommunityAvatar(community: community, radius: 24),
          title: Text(
            community.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${context.tr(community.spaceTypeLabel)} · ${context.trCount(community.memberCount, singular: community.isPublicProfile ? '{count} follower' : '{count} member', plural: community.isPublicProfile ? '{count} followers' : '{count} members')}',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          trailing: selected
              ? Icon(Icons.check_circle, color: colors.primary)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _CommunitySwitcherAction extends StatelessWidget {
  const _CommunitySwitcherAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: colors.primary.withValues(alpha: .08),
        foregroundColor: colors.primary,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
