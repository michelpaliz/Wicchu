import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/theme_menu.dart';
import '../community/community_page.dart';
import '../community/create_post_page.dart';
import '../community/post_card.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.repository});
  final CommunityRepository repository;

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
      const _ActivityTab(),
      _ProfileTab(repository: widget.repository),
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

class _HomeTabState extends State<_HomeTab> {
  late final Future<List<Community>> _communities;

  String _category = 'All';
  String _query = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _communities = widget.repository.listManagedCommunities();
  }

  Future<void> _createPost(Community community) async {
    final categories = await widget.repository.listCategories(community.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreatePostPage(community: community, categories: categories),
      ),
    );
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
      floatingActionButton: FutureBuilder<List<Community>>(
        future: _communities,
        builder: (context, snapshot) {
          final community = snapshot.data?.firstOrNull;
          if (community == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _createPost(community),
            icon: const Icon(Icons.add),
            label: Text(context.tr('New post')),
          );
        },
      ),
      body: FutureBuilder<List<Community>>(
        future: _communities,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final communities = snapshot.data!;
          final town =
              communities.firstOrNull?.town.name ?? context.tr('Your town');
          final normalizedQuery = _query.trim().toLowerCase();
          final firstCommunity = communities.firstOrNull;
          final newsMatches =
              normalizedQuery.isEmpty ||
              'news noticias water unavailable northern area maría agua zona norte ${context.tr('Water will be unavailable in the northern area tomorrow morning.').toLowerCase()}'
                  .contains(normalizedQuery);
          final marketMatches =
              normalizedQuery.isEmpty ||
              'marketplace mercado mountain bike sale carlos bicicleta montaña venta ${context.tr('Mountain bike for sale').toLowerCase()}'
                  .contains(normalizedQuery);
          final showNews =
              firstCommunity != null &&
              (_category == 'All' || _category == 'News') &&
              newsMatches;
          final showMarket =
              firstCommunity != null &&
              (_category == 'All' || _category == 'Marketplace') &&
              marketMatches;

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
              if (showNews) ...[
                PostCard(
                  category: 'News',
                  icon: '📢',
                  community: firstCommunity.name,
                  author: 'María P.',
                  time: '20 min',
                  text: context.tr(
                    'Water will be unavailable in the northern area tomorrow morning.',
                  ),
                  likes: 23,
                  comments: 8,
                ),
                const SizedBox(height: 12),
              ],
              if (showMarket) ...[
                PostCard(
                  category: 'Marketplace',
                  icon: '🛒',
                  community: firstCommunity.name,
                  author: 'Carlos M.',
                  time: '43 min',
                  text: context.tr('Mountain bike for sale'),
                  price: r'$180',
                  likes: 7,
                  comments: 12,
                ),
                const SizedBox(height: 12),
              ],
              if (!showNews && !showMarket)
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

class _ExploreTab extends StatelessWidget {
  const _ExploreTab({required this.repository});
  final CommunityRepository repository;

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
          future: repository.listManagedCommunities(),
          builder: (context, snapshot) => Column(
            children: [
              for (final community in snapshot.data ?? const <Community>[])
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Text('🏘')),
                    title: Text(community.name),
                    subtitle: Text(
                      context.tr('{count} members', {
                        'count': '${community.memberCount}',
                      }),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () {},
                      child: Text(context.tr('Joined')),
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Text('⚽')),
                  title: const Text('Town X Sports'),
                  subtitle: Text(
                    context.tr('{count} members', {'count': '620'}),
                  ),
                  trailing: FilledButton(
                    onPressed: null,
                    child: Text(context.tr('Join')),
                  ),
                ),
              ),
            ],
          ),
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
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Activity'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionLabel('Today'),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
          title: Text(context.tr('María replied to your post')),
          subtitle: Text(context.tr('12 minutes ago')),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.favorite_border)),
          title: Text(context.tr('Carlos reacted to your post')),
          subtitle: Text(context.tr('35 minutes ago')),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_add_alt)),
          title: Text(
            context.tr('Your request to join Town X Community was approved'),
          ),
          subtitle: Text(context.tr('2 hours ago')),
        ),
        const _SectionLabel('Yesterday'),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
          title: Text(context.tr('New announcement in Town X')),
          subtitle: Text(context.tr('Yesterday')),
        ),
      ],
    ),
  );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.repository});
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('You'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: CircleAvatar(radius: 42, child: Icon(Icons.person, size: 40)),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Michael P.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const Center(child: Text('@michael')),
        const SizedBox(height: 8),
        Center(child: Text(context.tr('4 Communities · 23 Posts'))),
        const SizedBox(height: 28),
        const _ProfileRow(icon: Icons.groups_outlined, label: 'My communities'),
        const _ProfileRow(icon: Icons.article_outlined, label: 'My posts'),
        const _ProfileRow(icon: Icons.bookmark_border, label: 'Saved posts'),
        const Divider(height: 28),
        const _ProfileRow(
          icon: Icons.shield_outlined,
          label: 'Communities I manage',
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
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      context.tr(text),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(context.tr(label)),
    trailing: const Icon(Icons.chevron_right),
  );
}
