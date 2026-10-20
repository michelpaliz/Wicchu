import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/wicchu_list_tile.dart';
import '../../widgets/wicchu_empty_illustration.dart';
import 'public_pages_discovery_page.dart';
import '../admin/create_community_page.dart';
import '../community/community_avatar.dart';
import '../community/community_profile_page.dart';

class PagesHubPage extends StatefulWidget {
  const PagesHubPage({
    super.key,
    required this.repository,
    required this.onChanged,
    this.followedOnly = false,
  });

  final CommunityRepository repository;
  final VoidCallback onChanged;
  final bool followedOnly;

  @override
  PagesHubPageState createState() => PagesHubPageState();
}

class PagesHubPageState extends State<PagesHubPage> {
  late Future<List<Community>> _pages = _load();
  Community? _selectedPage;

  bool _manages(Community page) =>
      page.myRole == CommunityRole.owner || page.myRole == CommunityRole.admin;

  Future<List<Community>> _load() async {
    final lists = await Future.wait([
      widget.repository.listJoinedCommunities(),
      widget.repository.listManagedCommunities(),
    ]);
    return {
      for (final page in lists.expand((list) => list))
        if (page.isPublicProfile &&
            (page.membershipStatus == null ||
                page.membershipStatus == MembershipStatus.active))
          page.id: page,
    }.values.toList();
  }

  Future<void> _refresh() async {
    final request = _load();
    setState(() {
      _pages = request;
    });
    try {
      final pages = await request;
      if (!mounted || !identical(_pages, request) || _selectedPage == null) {
        return;
      }
      setState(() {
        _selectedPage = pages
            .where((page) => page.id == _selectedPage!.id)
            .firstOrNull;
      });
    } catch (_) {
      // FutureBuilder displays the error and retry action.
    }
  }

  Future<void> refreshPages() => _refresh();

  Future<void> showPageSwitcher() async {
    try {
      final managed = (await _pages).where(_manages).toList();
      if (!mounted) return;
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheetContext) => ListView(
          shrinkWrap: true,
          children: [
            for (final page in managed)
              WicchuListTile(
                leading: CommunityAvatar(community: page, radius: 23),
                title: Text(page.name),
                subtitle: Text(sheetContext.tr(page.roleLabel(page.myRole!))),
                trailing: page.id == _selectedPage?.id
                    ? Icon(
                        WicchuIcons.check,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, page.id),
              ),
            WicchuListTile(
              leading: const Icon(WicchuIcons.plus),
              title: Text(sheetContext.tr('Create a page')),
              onTap: () => Navigator.pop(sheetContext, 'create'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'create') {
        await _create();
      } else {
        await _open(managed.firstWhere((page) => page.id == choice));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _open(Community page) async {
    if (widget.followedOnly) {
      Navigator.pop(context, page);
      return;
    }
    setState(() => _selectedPage = page);
  }

  void _backToPages() {
    setState(() => _selectedPage = null);
    _refresh();
    widget.onChanged();
  }

  Future<void> _create() async {
    final page = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(
          repository: widget.repository,
          initialType: CommunityType.publicProfile,
        ),
      ),
    );
    if (!mounted || page == null) return;
    await _refresh();
    if (!mounted) return;
    widget.onChanged();
    if (mounted) await _open(page);
  }

  Widget _row(Community page, {required bool managed}) => WicchuListTile(
    key: ValueKey('page-hub-${page.id}'),
    variant: WicchuListVariant.business,
    leading: CommunityAvatar(community: page, radius: 23),
    title: Text(page.name),
    subtitle: Text(
      managed
          ? '${context.tr(page.spaceTypeLabel)} · ${context.tr(page.roleLabel(page.myRole!))}'
          : '${context.tr(page.spaceTypeLabel)} · ${page.town.name}',
    ),
    trailing: const Icon(WicchuIcons.caretRight, size: 18),
    onTap: () => _open(page),
  );

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      context.tr(text),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Future<void> _explorePages() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PublicPagesDiscoveryPage(repository: widget.repository),
      ),
    );
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    widget.onChanged();
  }

  Widget _pagesEmptyState({required bool managed}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const ExcludeSemantics(
            child: WicchuEmptyIllustration(
              centerIcon: WicchuIcons.storefront,
              leftIcon: WicchuIcons.heart,
              rightIcon: WicchuIcons.megaphone,
              accentIcon: WicchuIcons.sparkle,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr(
              managed
                  ? 'You do not manage any public pages yet.'
                  : 'You do not follow any pages yet',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              managed
                  ? 'Create a public page for your business, organization or creator profile and share your news.'
                  : 'Discover businesses, organizations and creators that interest you and follow them to keep up with their news.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: managed ? _create : _explorePages,
            icon: Icon(
              managed ? WicchuIcons.plus : WicchuIcons.magnifyingGlass,
            ),
            label: Text(
              context.tr(managed ? 'Create a page' : 'Explore pages'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageList(List<Community> pages, {required bool managed}) {
    final count = context.trCount(
      pages.length,
      singular: managed ? '{count} managed page' : '{count} followed page',
      plural: managed ? '{count} managed pages' : '{count} followed pages',
    );
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: PageStorageKey(managed ? 'managed-pages' : 'followed-pages'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              count,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (pages.isEmpty) _pagesEmptyState(managed: managed),
          for (final page in pages) _row(page, managed: managed),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPage;
    if (selected != null) {
      return CommunityProfilePage(
        key: ValueKey(selected.id),
        community: selected,
        repository: widget.repository,
        embedded: true,
        onBack: _backToPages,
        onSwitchCommunity: showPageSwitcher,
        onCommunityUpdated: (page) {
          setState(() => _selectedPage = page);
          widget.onChanged();
        },
      );
    }
    return DefaultTabController(
      initialIndex: widget.followedOnly ? 1 : 0,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          toolbarHeight: 72,
          titleSpacing: 16,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Pages'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('Your pages and the ones you follow'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: context.tr('Create a page'),
                onPressed: _create,
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size.square(44),
                ),
                icon: const Icon(WicchuIcons.plus, size: 22),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: context.tr('My pages')),
              Tab(text: context.tr('Following')),
            ],
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Theme.of(context).dividerColor,
          ),
        ),
        body: FutureBuilder<List<Community>>(
          future: _pages,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 24),
                children: [
                  _message(context.trError(snapshot.error!)),
                  Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: Text(context.tr('Retry')),
                    ),
                  ),
                ],
              );
            }
            final pages = snapshot.data ?? const <Community>[];
            final managed = pages.where(_manages).toList();
            final followed = pages
                .where((page) => !_manages(page) && page.isJoined)
                .toList();
            return TabBarView(
              children: [
                _pageList(managed, managed: true),
                _pageList(followed, managed: false),
              ],
            );
          },
        ),
      ),
    );
  }
}
