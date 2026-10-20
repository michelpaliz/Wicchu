import 'local_news_settings_page.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
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
import 'community_insights_page.dart';
import 'community_rewards_page.dart';
import 'financial_support_page.dart';
import 'removed_posts_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.community,
    required this.repository,
    this.embedded = false,
    this.onCommunityChanged,
  });

  final bool embedded;
  final ValueChanged<Community>? onCommunityChanged;
  final Community community;
  final CommunityRepository repository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<AdminAttentionSummary> _summary;
  late Future<CommunityInsights> _insights;
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

  @override
  void didUpdateWidget(covariant AdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching communities must not keep the previous community's menu.
    if (oldWidget.community.id != widget.community.id) {
      _community = widget.community;
      _reload();
    }
  }

  void _reload() {
    _summary = repository.getAdminAttention(community.id);
    if (_canConfigure && !community.isPublicProfile) {
      _insights = repository.getCommunityInsights(community.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: BackButton(
                onPressed: () => Navigator.pop(context, community),
              ),
              title: Text(
                context.tr(
                  community.isPublicProfile
                      ? (community.profileCategory ==
                                ProfileCategory.localBusiness
                            ? 'Manage business'
                            : 'Manage profile')
                      : 'Manage community',
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.embedded)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.embedded
                  ? null
                  : () => Navigator.pop(context, community),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CommunityAvatar(community: community, radius: 27),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.trCount(community.memberCount, singular: community.isPublicProfile ? '{count} follower' : '{count} member', plural: community.isPublicProfile ? '{count} followers' : '{count} members')} · ${context.tr(community.isPublicProfile
                                ? community.spaceTypeLabel
                                : community.visibility == CommunityVisibility.public
                                ? 'Public community'
                                : 'Private community')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!widget.embedded)
                      const Icon(WicchuIcons.caretRight, size: 20),
                  ],
                ),
              ),
            ),
          if (!widget.embedded) const SizedBox(height: 10),
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
              return _AttentionPanel(
                summary: summary,
                includeMembershipRequests: _canConfigure,
                onPendingPosts: _openPendingPosts,
                onPromotions: () => _openQueue(
                  PromotionReviewPage(
                    community: community,
                    repository: repository,
                  ),
                ),
                onReports: () => _openQueue(
                  ReportsQueuePage(
                    community: community,
                    repository: repository,
                  ),
                ),
                onMembershipRequests: () => _openQueue(
                  MembershipRequestsPage(
                    community: community,
                    repository: repository,
                  ),
                ),
              );
            },
          ),
          if (community.myRole == CommunityRole.owner &&
              community.isPublicProfile)
            _MenuSection(
              label: 'Monetization',
              children: [
                _MenuRow(
                  icon: WicchuIcons.heart,
                  label: 'Financial support',
                  description:
                      'Apply to receive voluntary support in the future',
                  onTap: () => _openQueue(
                    FinancialSupportPage(
                      page: community,
                      repository: repository,
                    ),
                  ),
                ),
              ],
            ),
          if (_canConfigure)
            _MenuSection(
              label: 'Content',
              children: [
                _MenuRow(
                  icon: WicchuIcons.chartLineUp,
                  label: 'Statistics and activity',
                  description: 'Growth, posts and interactions',
                  onTap:
                      _canConfigure &&
                          (!community.isPublicProfile ||
                              community.myRole == CommunityRole.owner ||
                              community.canViewPageAnalytics)
                      ? () => _openQueue(
                          CommunityInsightsPage(
                            community: community,
                            repository: repository,
                          ),
                        )
                      : () => _openOverview(),
                ),
                if (_canConfigure)
                  _MenuRow(
                    icon: WicchuIcons.folder,
                    label: 'Categories',
                    description: community.isPublicProfile
                        ? 'Manage page categories'
                        : 'Manage community categories',
                    onTap: () => _openQueue(
                      CategoryManagementPage(
                        community: community,
                        repository: repository,
                      ),
                    ),
                  ),
                // Server-computed: pilot access plus owner/admin role.
                if (community.canManageLocalNews)
                  _MenuRow(
                    icon: WicchuIcons.newspaper,
                    label: 'Automated news',
                    description:
                        'Find relevant articles for this community automatically',
                    onTap: () => _openQueue(
                      LocalNewsSettingsPage(
                        community: community,
                        repository: repository,
                      ),
                    ),
                  ),
                _MenuRow(
                  icon: WicchuIcons.listChecks,
                  label: 'Rules',
                  description: community.isPublicProfile
                      ? 'Define the page rules'
                      : 'Define the community rules',
                  onTap: () => _openQueue(
                    RuleManagementPage(
                      community: community,
                      repository: repository,
                    ),
                  ),
                ),
              ],
            ),
          if (_canConfigure)
            _MenuSection(
              label: 'People',
              children: [
                if (_canConfigure)
                  _MenuRow(
                    icon: WicchuIcons.users,
                    label: community.isPublicProfile ? 'Followers' : 'Members',
                    description: community.isPublicProfile
                        ? 'Manage followers'
                        : 'Members, roles and permissions',
                    onTap: () => _openQueue(
                      MemberManagementPage(
                        community: community,
                        repository: repository,
                      ),
                    ),
                  ),
                _MenuRow(
                  icon: WicchuIcons.userPlus,
                  label: 'Invitations',
                  description: community.isPublicProfile
                      ? 'Manage page invitations'
                      : 'Invite people and manage requests',
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
                icon: WicchuIcons.shield,
                label: 'Moderation',
                description: 'Review content and manage reports',
                onTap: () => _openQueue(
                  ReportsQueuePage(
                    community: community,
                    repository: repository,
                  ),
                ),
              ),
              _MenuRow(
                icon: WicchuIcons.fileArrowUp,
                label: 'Removed posts',
                description: 'Review and restore posts removed by moderators',
                onTap: () => _openQueue(
                  RemovedPostsPage(
                    community: community,
                    repository: repository,
                  ),
                ),
              ),
            ],
          ),
          if (_canConfigure && !community.isPublicProfile)
            _MenuSection(
              label: 'Rewards',
              children: [
                FutureBuilder<CommunityInsights>(
                  future: _insights,
                  builder: (context, snapshot) => _MenuRow(
                    icon: WicchuIcons.path,
                    label: 'Rewards roadmap',
                    description: snapshot.hasData
                        ? _rewardsDescription(context, snapshot.data!)
                        : context.tr(
                            snapshot.hasError ? 'View roadmap' : 'Loading…',
                          ),
                    onTap: () => _openQueue(
                      CommunityRewardsPage(
                        community: community,
                        repository: repository,
                      ),
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
                  icon: WicchuIcons.gearSix,
                  label: 'Settings',
                  description: community.isPublicProfile
                      ? 'Configure your page'
                      : 'Configure your community',
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
      if (updated != null) widget.onCommunityChanged?.call(updated);
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
    if (updated != null && mounted) {
      setState(() => _community = updated);
      widget.onCommunityChanged?.call(updated);
    }
  }
}

String _rewardsDescription(BuildContext context, CommunityInsights insights) {
  final reward = insights.monetization;
  final enrollment = reward.enrollment;
  if (!enrollment.accepted) {
    if (enrollment.status == 'pending') {
      return context.tr('Reward request under review');
    }
    if (enrollment.status == 'rejected') {
      return context.tr('Update your rewards request');
    }
    if (enrollment.status == 'approved') {
      return context.tr('Review pilot terms');
    }
    if (reward.eligible || enrollment.requested) {
      return context.tr('Request access');
    }
  }
  final tier =
      reward.nextTier ??
      (enrollment.accepted ? reward.currentTier : null) ??
      (reward.tiers.isEmpty ? null : reward.tiers.first);
  if (tier == null) return context.tr('View roadmap');
  final requirements = [
    (insights.totalMembers, tier.memberTarget),
    (insights.monthlyActiveUsers, tier.monthlyActiveTarget),
    (insights.posts30d, tier.postsTarget),
    (insights.interactions30d, tier.interactionsTarget),
    (insights.uniqueContributors30d, tier.contributorsTarget),
  ].where((item) => item.$2 > 0).toList();
  if (requirements.isEmpty) return context.tr('View roadmap');
  final progress =
      requirements.fold<double>(
        0,
        (sum, item) => sum + (item.$1 / item.$2).clamp(0, 1),
      ) /
      requirements.length;
  return context.tr(
    enrollment.accepted
        ? '{progress}% completed'
        : 'Stage 1 of 4 · {progress}% completed',
    {'progress': '${(progress * 100).round()}'},
  );
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.summary,
    required this.includeMembershipRequests,
    required this.onPendingPosts,
    required this.onPromotions,
    required this.onReports,
    required this.onMembershipRequests,
  });

  final AdminAttentionSummary summary;
  final bool includeMembershipRequests;
  final VoidCallback onPendingPosts;
  final VoidCallback onPromotions;
  final VoidCallback onReports;
  final VoidCallback onMembershipRequests;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total =
        summary.pendingPosts +
        summary.pendingPromotions +
        summary.openReports +
        (includeMembershipRequests ? summary.membershipRequests : 0);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(WicchuIcons.checkCircle, color: colors.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('All caught up'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    context.tr('No pending tasks'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: colors.errorContainer.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(WicchuIcons.warningCircle, color: colors.error, size: 21),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('Needs your attention'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$total',
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (summary.pendingPosts > 0)
              _ActionRow(
                icon: WicchuIcons.clipboardText,
                label: 'Posts awaiting approval',
                count: summary.pendingPosts,
                onTap: onPendingPosts,
              ),
            if (summary.pendingPromotions > 0)
              _ActionRow(
                icon: WicchuIcons.megaphone,
                label: 'Promotion requests',
                count: summary.pendingPromotions,
                onTap: onPromotions,
              ),
            if (summary.openReports > 0)
              _ActionRow(
                icon: WicchuIcons.flag,
                label: 'Reports',
                count: summary.openReports,
                onTap: onReports,
              ),
            if (includeMembershipRequests && summary.membershipRequests > 0)
              _ActionRow(
                icon: WicchuIcons.userPlus,
                label: 'Membership requests',
                count: summary.membershipRequests,
                onTap: onMembershipRequests,
              ),
          ],
        ),
      ),
    );
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
    dense: true,
    minTileHeight: 44,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, size: 19),
    title: Text(context.tr(label), style: const TextStyle(fontSize: 14)),
    trailing: Text(
      '$count',
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
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
    dense: true,
    minTileHeight: 54,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
    title: Text(
      context.tr(label),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      context.tr(description),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.25,
      ),
    ),
    trailing: const Icon(WicchuIcons.caretRight, size: 19),
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
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            context.tr(label).toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: .5,
            ),
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 42,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .08),
                ),
              children[i],
            ],
          ],
        ),
      ],
    ),
  );
}
