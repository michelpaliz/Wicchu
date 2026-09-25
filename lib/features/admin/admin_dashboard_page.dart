import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'pending_posts_page.dart';
import 'admin_overview_page.dart';
import 'admin_review_queues.dart';
import 'admin_management_pages.dart';
import 'promotion_review_page.dart';
import 'rule_management_page.dart';
import '../community/community_invitations_page.dart';
import '../community/community_avatar.dart';

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

  bool get _canConfigure =>
      community.myRole == CommunityRole.owner ||
      community.myRole == CommunityRole.admin;
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
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context, community)),
        title: Text(context.tr('Manage community')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CommunityAvatar(community: community, radius: 32),
              title: Text(
                community.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${context.trCount(community.memberCount, singular: '{count} member', plural: '{count} members')} · ${context.tr(community.visibility == CommunityVisibility.public ? 'Public community' : 'Private community')}',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, community),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<AdminAttentionSummary>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(context.trError(snapshot.error!)),
                    TextButton(
                      onPressed: () => setState(_reload),
                      child: Text(context.tr('Retry')),
                    ),
                  ],
                );
              }
              final summary = snapshot.data!;
              if (summary.pendingPosts +
                      summary.pendingPromotions +
                      summary.openReports +
                      (_canConfigure ? summary.membershipRequests : 0) ==
                  0) {
                final colors = Theme.of(context).colorScheme;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colors.primary,
                        child: Icon(
                          Icons.check_rounded,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('All caught up'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('Nothing needs your attention.'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.tr('Needs your attention'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (summary.pendingPosts > 0)
                      _ActionRow(
                        icon: Icons.pending_actions,
                        label: 'Posts awaiting approval',
                        count: summary.pendingPosts,
                        onTap: _openPendingPosts,
                      ),
                    if (summary.pendingPromotions > 0)
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
                    if (summary.openReports > 0)
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
                    if (_canConfigure && summary.membershipRequests > 0)
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
          _MenuSection(
            label: 'Content',
            children: [
              _MenuRow(
                icon: Icons.bar_chart_rounded,
                label: 'Overview',
                description: 'Community activity and key details',
                onTap: () => _openOverview(),
              ),
              if (_canConfigure)
                _MenuRow(
                  icon: Icons.folder_outlined,
                  label: 'Categories',
                  description: 'Manage community categories',
                  onTap: () => _openQueue(
                    CategoryManagementPage(
                      community: community,
                      repository: repository,
                    ),
                  ),
                ),
              _MenuRow(
                icon: Icons.rule_outlined,
                label: 'Rules',
                description: 'Define the community rules',
                onTap: () => _openQueue(
                  RuleManagementPage(
                    community: community,
                    repository: repository,
                  ),
                ),
              ),
            ],
          ),
          _MenuSection(
            label: 'People',
            children: [
              if (_canConfigure)
                _MenuRow(
                  icon: Icons.group_outlined,
                  label: 'Members',
                  description: 'Manage community members',
                  onTap: () => _openQueue(
                    MemberManagementPage(
                      community: community,
                      repository: repository,
                    ),
                  ),
                ),
              _MenuRow(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Invitations',
                description: 'Manage community invitations',
                onTap: () => _openQueue(
                  CommunityInvitationsPage(
                    community: community,
                    repository: repository,
                  ),
                ),
              ),
            ],
          ),
          _MenuSection(
            label: 'Security',
            children: [
              _MenuRow(
                icon: Icons.shield_outlined,
                label: 'Moderation',
                description: 'Review content and manage reports',
                onTap: () => _openQueue(
                  ReportsQueuePage(
                    community: community,
                    repository: repository,
                  ),
                ),
              ),
            ],
          ),
          if (_canConfigure)
            _MenuSection(
              label: 'Configuration',
              children: [
                _MenuRow(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  description: 'Configure your community',
                  onTap: _openSettings,
                ),
              ],
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Future<void> _openOverview() async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminOverviewPage(community: community, repository: repository),
      ),
    );
    if (mounted) {
      setState(() {
        if (updated != null) _community = updated;
        _reload();
      });
    }
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
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.description,
    this.onTap,
  });
  final String description;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 26),
    title: Text(
      context.tr(label),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      context.tr(description),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            context.tr(label).toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: .5,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .08),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .08),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
