import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../widgets/wicchu_logo.dart';
import 'pending_posts_page.dart';
import 'admin_review_queues.dart';
import 'admin_management_pages.dart';
import 'promotion_review_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<AdminAttentionSummary> _summary;
  late Community _community = widget.community;

  Community get community => _community;
  CommunityRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _summary = repository.getAdminAttention(community.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const WicchuTitle()),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            community.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.trCount(
              community.memberCount,
              singular: '{count} member',
              plural: '{count} members',
            ),
          ),
          const SizedBox(height: 28),
          Text(
            context.tr('Needs your attention'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FutureBuilder<AdminAttentionSummary>(
            future: _summary,
            builder: (context, snapshot) {
              final summary = snapshot.data ?? const AdminAttentionSummary();
              return Card(
                child: Column(
                  children: [
                    _ActionRow(
                      icon: Icons.pending_actions,
                      label: 'Posts awaiting approval',
                      count: summary.pendingPosts,
                      onTap: _openPendingPosts,
                    ),
                    _ActionRow(
                      icon: Icons.campaign_outlined,
                      label: 'Promotion requests',
                      count: summary.pendingPromotions,
                      onTap: () => _openQueue(
                        PromotionReviewPage(
                          community: community,
                          repository: repository,
                        ),
                      ),
                    ),
                    _ActionRow(
                      icon: Icons.flag_outlined,
                      label: 'Reports',
                      count: summary.openReports,
                      onTap: () => _openQueue(
                        ReportsQueuePage(
                          community: community,
                          repository: repository,
                        ),
                      ),
                    ),
                    _ActionRow(
                      icon: Icons.person_add_alt,
                      label: 'Membership requests',
                      count: summary.membershipRequests,
                      onTap: () => _openQueue(
                        MembershipRequestsPage(
                          community: community,
                          repository: repository,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            context.tr('Community'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.insights_outlined,
            label: 'Overview',
            onTap: () => _openQueue(AdminOverviewPage(community: community)),
          ),
          _MenuRow(
            icon: Icons.folder_outlined,
            label: 'Categories',
            onTap: () => _openQueue(
              CategoryManagementPage(
                community: community,
                repository: repository,
              ),
            ),
          ),
          _MenuRow(
            icon: Icons.group_outlined,
            label: 'Members',
            onTap: () => _openQueue(
              MemberManagementPage(
                community: community,
                repository: repository,
              ),
            ),
          ),
          _MenuRow(
            icon: Icons.shield_outlined,
            label: 'Moderation',
            onTap: () => _openQueue(
              ReportsQueuePage(community: community, repository: repository),
            ),
          ),
          _MenuRow(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: _openSettings,
          ),
        ],
      ),
    );
  }

  Future<void> _openPendingPosts() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PendingPostsPage(community: community, repository: repository),
      ),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _openQueue(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(_reload);
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunitySettingsPage(community: community, repository: repository),
      ),
    );
    if (updated != null && mounted) setState(() => _community = updated);
  }
}

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key, required this.community});
  final Community community;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Overview'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          leading: const Icon(Icons.group_outlined),
          title: Text(context.tr('Members')),
          trailing: Text('${community.memberCount}'),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(context.tr('Town')),
          trailing: Text(community.town.name),
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: Text(context.tr('Visibility')),
          trailing: Text(context.tr(community.visibility.name)),
        ),
        ListTile(
          leading: const Icon(Icons.approval_outlined),
          title: Text(context.tr('Post approval')),
          trailing: Text(
            context.tr(community.approvalRequired ? 'Required' : 'Automatic'),
          ),
        ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.count,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(context.tr(label)),
    trailing: Badge(label: Text('$count'), isLabelVisible: count > 0),
    onTap: onTap,
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(context.tr(label)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
