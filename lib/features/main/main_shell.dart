import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.repository});
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wicchu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      floatingActionButton: FutureBuilder<List<Community>>(
        future: repository.listManagedCommunities(),
        builder: (context, snapshot) => FloatingActionButton(
          onPressed: snapshot.data?.firstOrNull == null
              ? null
              : () async {
                  final community = snapshot.data!.first;
                  final categories = await repository.listCategories(
                    community.id,
                  );
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePostPage(
                          community: community,
                          categories: categories,
                        ),
                      ),
                    );
                  }
                },
          child: const Icon(Icons.add),
        ),
      ),
      body: FutureBuilder<List<Community>>(
        future: repository.listManagedCommunities(),
        builder: (context, snapshot) {
          final communities = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
            children: [
              Text(
                'Your communities',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: communities.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final community = communities[index];
                    return SizedBox(
                      width: 210,
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityPage(
                                community: community,
                                repository: repository,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Text(
                                  '🏘',
                                  style: TextStyle(fontSize: 26),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        community.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${community.memberCount} members',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'following', label: Text('Following')),
                  ButtonSegment(value: 'latest', label: Text('Latest')),
                ],
                selected: const {'following'},
                onSelectionChanged: (_) {},
              ),
              const SizedBox(height: 18),
              if (communities case [final community, ...]) ...[
                PostCard(
                  category: 'News',
                  icon: '📢',
                  community: community.name,
                  author: 'María P.',
                  time: '20 min',
                  text:
                      'Water will be unavailable in the northern area tomorrow morning.',
                  likes: 23,
                  comments: 8,
                ),
                const SizedBox(height: 14),
                PostCard(
                  category: 'Marketplace',
                  icon: '🛒',
                  community: community.name,
                  author: 'Carlos M.',
                  time: '43 min',
                  text: 'Mountain bike for sale',
                  price: r'$180',
                  showImage: true,
                  likes: 7,
                  comments: 12,
                ),
              ],
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
      title: const Text('Explore'),
      actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '📍 Near you',
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
                    subtitle: Text('${community.memberCount} members'),
                    trailing: FilledButton.tonal(
                      onPressed: () {},
                      child: const Text('Joined'),
                    ),
                  ),
                ),
              const Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('⚽')),
                  title: Text('Town X Sports'),
                  subtitle: Text('620 members'),
                  trailing: FilledButton(onPressed: null, child: Text('Join')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Popular near you',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('🐕 Animal Lovers')),
            Chip(label: Text('⚽ Football')),
            Chip(label: Text('🎓 Students')),
            Chip(label: Text('🚴 Cycling')),
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
    appBar: AppBar(title: const Text('Activity')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SectionLabel('Today'),
        ListTile(
          leading: CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
          title: Text('María replied to your post'),
          subtitle: Text('12 minutes ago'),
        ),
        ListTile(
          leading: CircleAvatar(child: Icon(Icons.favorite_border)),
          title: Text('Carlos reacted to your post'),
          subtitle: Text('35 minutes ago'),
        ),
        ListTile(
          leading: CircleAvatar(child: Icon(Icons.person_add_alt)),
          title: Text('Your request to join Town X Community was approved'),
          subtitle: Text('2 hours ago'),
        ),
        _SectionLabel('Yesterday'),
        ListTile(
          leading: CircleAvatar(child: Icon(Icons.campaign_outlined)),
          title: Text('New announcement in Town X'),
          subtitle: Text('Yesterday'),
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
    appBar: AppBar(title: const Text('You')),
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
        const Center(child: Text('4 Communities · 23 Posts')),
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
      text,
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
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
  );
}
