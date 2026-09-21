import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wicchu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            community.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 28),
          Text(
            'Needs your attention',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AdminAttentionSummary>(
            future: repository.getAdminAttention(community.id),
            builder: (context, snapshot) {
              final summary = snapshot.data ?? const AdminAttentionSummary();
              return Card(
                child: Column(
                  children: [
                    _ActionRow(
                      icon: Icons.pending_actions,
                      label: 'Posts awaiting approval',
                      count: summary.pendingPosts,
                    ),
                    _ActionRow(
                      icon: Icons.flag_outlined,
                      label: 'Reports',
                      count: summary.openReports,
                    ),
                    _ActionRow(
                      icon: Icons.person_add_alt,
                      label: 'Membership requests',
                      count: summary.membershipRequests,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text('Community', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const _MenuRow(icon: Icons.insights_outlined, label: 'Overview'),
          const _MenuRow(icon: Icons.folder_outlined, label: 'Categories'),
          const _MenuRow(icon: Icons.group_outlined, label: 'Members'),
          const _MenuRow(icon: Icons.shield_outlined, label: 'Moderation'),
          const _MenuRow(icon: Icons.settings_outlined, label: 'Settings'),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.count,
  });
  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: Badge(label: Text('$count'), isLabelVisible: count > 0),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
  );
}
