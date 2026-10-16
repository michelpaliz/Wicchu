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
  });

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

  void _reload() {
    _summary = repository.getAdminAttention(community.id);
    _insights = repository.getCommunityInsights(community.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context, community)),
        title: Text(
          context.tr(
            community.isPublicProfile
                ? (community.profileCategory == ProfileCategory.localBusiness
                      ? 'Manage business'
                      : 'Manage profile')
                : 'Manage community',
          ),
        ),
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
                  '${context.trCount(community.memberCount, singular: community.isPublicProfile ? '{count} follower' : '{count} member', plural: community.isPublicProfile ? '{count} followers' : '{count} members')} · ${context.tr(community.isPublicProfile
                      ? community.spaceTypeLabel
                      : community.visibility == CommunityVisibility.public
                      ? 'Public community'
                      : 'Private community')}',
                ),
              ),
              trailing: const Icon(WicchuIcons.caretRight),
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
                        child: Icon(WicchuIcons.check, color: colors.onPrimary),
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
                        icon: WicchuIcons.clipboardText,
                        label: 'Posts awaiting approval',
                        count: summary.pendingPosts,
                        onTap: _openPendingPosts,
                      ),
                    if (summary.pendingPromotions > 0)
                      _ActionRow(
                        icon: WicchuIcons.megaphone,
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
                        icon: WicchuIcons.flag,
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
                        icon: WicchuIcons.userPlus,
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
          if (_canConfigure && !community.isPublicProfile) ...[
            const SizedBox(height: 16),
            FutureBuilder<CommunityInsights>(
              future: _insights,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _MonetizationLoadingCard();
                }
                if (snapshot.hasError) {
                  return const SizedBox.shrink();
                }
                return _MonetizationCard(
                  insights: snapshot.data!,
                  onDetails: () => _openQueue(
                    CommunityRewardsPage(
                      community: community,
                      repository: repository,
                    ),
                  ),
                  onInvite: () => _openQueue(
                    CommunityInvitationsPage(
                      community: community,
                      repository: repository,
                    ),
                  ),
                );
              },
            ),
          ],
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
          _MenuSection(
            label: 'Content',
            children: [
              _MenuRow(
                icon: WicchuIcons.chartBar,
                label: 'Overview',
                description: community.isPublicProfile
                    ? 'Page activity and key details'
                    : 'Community activity and key details',
                onTap: () => _openOverview(),
              ),
              if (_canConfigure &&
                  (!community.isPublicProfile ||
                      community.canViewPageAnalytics))
                _MenuRow(
                  icon: WicchuIcons.chartLineUp,
                  label: 'Insights',
                  description: 'Understand community growth and engagement',
                  onTap: () => _openQueue(
                    CommunityInsightsPage(
                      community: community,
                      repository: repository,
                    ),
                  ),
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
          _MenuSection(
            label: 'People',
            children: [
              if (_canConfigure)
                _MenuRow(
                  icon: WicchuIcons.users,
                  label: community.isPublicProfile ? 'Followers' : 'Members',
                  description: community.isPublicProfile
                      ? 'Manage followers'
                      : 'Manage community members',
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
                    : 'Manage community invitations',
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

class _MonetizationLoadingCard extends StatelessWidget {
  const _MonetizationLoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(20),
      child: LinearProgressIndicator(),
    ),
  );
}

class _MonetizationCard extends StatelessWidget {
  const _MonetizationCard({
    required this.insights,
    required this.onDetails,
    required this.onInvite,
  });

  final CommunityInsights insights;
  final VoidCallback onDetails;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final eligibility = insights.monetization;
    final colors = Theme.of(context).colorScheme;
    if (!eligibility.enrollment.accepted) {
      final enrollment = eligibility.enrollment;
      final pending = enrollment.status == 'pending';
      final approved = enrollment.status == 'approved';
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(WicchuIcons.currencyDollar, color: colors.primary),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  pending
                      ? 'Reward request under review'
                      : 'Community Rewards pilot',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  pending
                      ? 'Wicchu will contact you after reviewing your country.'
                      : approved
                      ? 'Your request was approved. Accept the terms to join.'
                      : 'Send a short request to check availability in your country.',
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onDetails,
                child: Text(
                  context.tr(
                    pending
                        ? 'View request'
                        : approved
                        ? 'Review pilot terms'
                        : 'Request access',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final earned = eligibility.currentTier;
    final target = eligibility.nextTier ?? earned;
    if (target == null) return const SizedBox.shrink();
    double progress(num value, num goal) =>
        goal <= 0 ? 1 : (value / goal).clamp(0.0, 1.0).toDouble();
    String tierName(String id) => context.tr(switch (id) {
      'active' => 'Active',
      'growing' => 'Growing',
      'high_impact' => 'High Impact',
      _ => id,
    });
    String reward(CommunityRewardTier tier) {
      final euros = tier.monthlyRewardCents / 100;
      final amount = euros == euros.roundToDouble()
          ? euros.toInt().toString()
          : euros.toStringAsFixed(2);
      return eligibility.currency == 'USD' ? '\$$amount' : '$amount €';
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  earned != null
                      ? WicchuIcons.confetti
                      : WicchuIcons.currencyDollar,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(
                      earned != null
                          ? 'Monthly community reward'
                          : 'Grow and earn',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _EligibilityBadge(eligible: earned != null),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                earned != null
                    ? 'You reached the {level} level and can earn {amount} every qualifying month.'
                    : 'Build a genuine, active community to unlock a monthly Wicchu reward.',
                earned != null
                    ? {'level': tierName(earned.id), 'amount': reward(earned)}
                    : const {},
              ),
            ),
            if (eligibility.tiers.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                context.tr('Your reward journey'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (final tier in eligibility.tiers) ...[
                _RewardLevelTile(
                  name: tierName(tier.id),
                  reward: reward(tier),
                  state: tier.qualified
                      ? (eligibility.nextTier == null && earned?.id == tier.id
                            ? _RewardStepState.current
                            : _RewardStepState.completed)
                      : tier.id == target.id
                      ? _RewardStepState.current
                      : _RewardStepState.locked,
                ),
                if (tier != eligibility.tiers.last) const SizedBox(height: 8),
              ],
            ],
            if (earned != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  context.tr('Estimated reward: {amount} per month', {
                    'amount': reward(earned),
                  }),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              context.tr('{level} level requirements', {
                'level': tierName(target.id),
              }),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _MonetizationRequirement(
              icon: WicchuIcons.users,
              label: context.tr('Members'),
              value: insights.totalMembers,
              target: target.memberTarget,
              progress: progress(insights.totalMembers, target.memberTarget),
            ),
            const SizedBox(height: 16),
            _MonetizationRequirement(
              icon: WicchuIcons.circleFill,
              label: context.tr('Monthly active members'),
              value: insights.monthlyActiveUsers,
              target: target.monthlyActiveTarget,
              progress: progress(
                insights.monthlyActiveUsers,
                target.monthlyActiveTarget,
              ),
              iconColor: Colors.green,
            ),
            const SizedBox(height: 16),
            _MonetizationRequirement(
              icon: WicchuIcons.article,
              label: context.tr('Useful posts in 30 days'),
              value: insights.posts30d,
              target: target.postsTarget,
              progress: progress(insights.posts30d, target.postsTarget),
            ),
            const SizedBox(height: 16),
            _MonetizationRequirement(
              icon: WicchuIcons.heart,
              label: context.tr('Meaningful interactions in 30 days'),
              value: insights.interactions30d,
              target: target.interactionsTarget,
              progress: progress(
                insights.interactions30d,
                target.interactionsTarget,
              ),
            ),
            const SizedBox(height: 16),
            _MonetizationRequirement(
              icon: WicchuIcons.users,
              label: context.tr('Unique contributors in 30 days'),
              value: insights.uniqueContributors30d,
              target: target.contributorsTarget,
              progress: progress(
                insights.uniqueContributors30d,
                target.contributorsTarget,
              ),
            ),
            if (target.retentionTargetPercent > 0) ...[
              const SizedBox(height: 16),
              if (insights.retentionDataAvailable)
                _MonetizationRequirement(
                  icon: WicchuIcons.chartLineUp,
                  label: context.tr('Monthly member retention'),
                  value: insights.monthlyRetentionRate,
                  target: target.retentionTargetPercent,
                  progress: progress(
                    insights.monthlyRetentionRate,
                    target.retentionTargetPercent,
                  ),
                  suffix: '%',
                )
              else
                Text(context.tr('Not enough retention data')),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  eligibility.goodStanding
                      ? WicchuIcons.shieldCheck
                      : WicchuIcons.shieldWarning,
                  color: eligibility.goodStanding ? Colors.green : colors.error,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr('Community status'))),
                Text(
                  context.tr(
                    eligibility.goodStanding ? 'Good standing' : 'Restricted',
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: eligibility.goodStanding
                        ? Colors.green
                        : colors.error,
                  ),
                ),
              ],
            ),
            if (earned == null) ...[
              const SizedBox(height: 20),
              Text(
                context.tr(
                  'Complete every requirement to reach {level} and earn {amount} monthly.',
                  {'level': tierName(target.id), 'amount': reward(target)},
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onInvite,
                icon: const Icon(WicchuIcons.userPlus),
                label: Text(context.tr('Invite people')),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Text(
                context.tr(
                  eligibility.reviewRequired
                      ? 'Rewards are reviewed after each qualifying month. Genuine activity only; spam and artificial engagement do not count.'
                      : 'Keep meeting these requirements every month to retain your reward.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              context.tr('How rewards work'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Wicchu checks the previous 30 days. Meet every requirement and remain in good standing. Approved rewards are paid the following month.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  WicchuIcons.currencyDollar,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Payment setup'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        context.tr(
                          'Required before your first payment. Wicchu will request verified payment details after you qualify.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onDetails,
              icon: const Icon(WicchuIcons.chartBar),
              label: Text(context.tr('View reward details')),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RewardStepState { completed, current, locked }

class _RewardLevelTile extends StatelessWidget {
  const _RewardLevelTile({
    required this.name,
    required this.reward,
    required this.state,
  });

  final String name;
  final String reward;
  final _RewardStepState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = state != _RewardStepState.locked;
    final color = state == _RewardStepState.completed
        ? Colors.green
        : active
        ? colors.primary
        : colors.onSurfaceVariant;
    final label = switch (state) {
      _RewardStepState.completed => 'Completed',
      _RewardStepState.current => 'In progress',
      _RewardStepState.locked => 'Locked',
    };
    final icon = switch (state) {
      _RewardStepState.completed => WicchuIcons.check,
      _RewardStepState.current => WicchuIcons.circleFill,
      _RewardStepState.locked => WicchuIcons.lockKey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? .10 : .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: .15),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  context.tr(label),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          Text(
            context.tr('{amount}/month', {'amount': reward}),
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _EligibilityBadge extends StatelessWidget {
  const _EligibilityBadge({required this.eligible});
  final bool eligible;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: (eligible ? Colors.green : Theme.of(context).colorScheme.secondary)
          .withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      context.tr(eligible ? 'Eligible' : 'Not yet eligible'),
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: eligible
            ? Colors.green.shade700
            : Theme.of(context).colorScheme.secondary,
      ),
    ),
  );
}

class _MonetizationRequirement extends StatelessWidget {
  const _MonetizationRequirement({
    required this.icon,
    required this.label,
    required this.value,
    required this.target,
    required this.progress,
    this.iconColor,
    this.suffix = '',
  });

  final IconData icon;
  final String label;
  final num value;
  final num target;
  final double progress;
  final Color? iconColor;
  final String suffix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            '${_display(value)}$suffix / ${_display(target)}$suffix',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: progress, minHeight: 8),
    ],
  );

  static String _display(num value) => value is double && value % 1 != 0
      ? value.toStringAsFixed(1)
      : value.toInt().toString();
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
    trailing: const Icon(WicchuIcons.caretRight),
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
