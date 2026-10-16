import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class PlatformModerationPage extends StatefulWidget {
  const PlatformModerationPage({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<PlatformModerationPage> createState() => _PlatformModerationPageState();
}

class _PlatformModerationPageState extends State<PlatformModerationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) _reload();
    });
  late Future<List<PlatformReport>> _reports = _load();
  late Future<List<CommunityRewardRequest>> _rewardRequests = widget.repository
      .listCommunityRewardRequests();
  late Future<List<PlatformRewardPayout>> _rewardPayouts = widget.repository
      .listPlatformRewardPayouts();
  late Future<PlatformAnalytics> _analytics = widget.repository
      .getPlatformAnalytics();
  late Future<List<FinancialSupportApplication>> _supportApplications = widget
      .repository
      .listFinancialSupportApplications();
  final Set<String> _saving = {};

  Future<List<PlatformReport>> _load() =>
      widget.repository.listPlatformReports(resolved: _tabs.index == 1);

  void _reload() => setState(() {
    if (_tabs.index == 2) {
      _rewardRequests = widget.repository.listCommunityRewardRequests();
    } else if (_tabs.index == 3) {
      _rewardPayouts = widget.repository.listPlatformRewardPayouts();
    } else if (_tabs.index == 4) {
      _analytics = widget.repository.getPlatformAnalytics();
    } else if (_tabs.index == 5) {
      _supportApplications = widget.repository
          .listFinancialSupportApplications();
    } else {
      _reports = _load();
    }
  });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Wicchu Safety')),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: [
          Tab(text: context.tr('Pending')),
          Tab(text: context.tr('Resolved')),
          Tab(text: context.tr('Rewards')),
          Tab(text: context.tr('Payouts')),
          Tab(text: context.tr('Analytics')),
          Tab(text: context.tr('Financial support')),
        ],
      ),
    ),
    body: _tabs.index >= 2
        ? (_tabs.index == 2
              ? _buildRewardRequests()
              : _tabs.index == 3
              ? _buildRewardPayouts()
              : _tabs.index == 4
              ? _buildAnalytics()
              : _buildSupportApplications())
        : FutureBuilder<List<PlatformReport>>(
            future: _reports,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(WicchuIcons.arrowsClockwise),
                    label: Text(context.trError(snapshot.error!)),
                  ),
                );
              }
              final reports = snapshot.data ?? const [];
              if (reports.isEmpty) {
                return Center(
                  child: Text(
                    context.tr(
                      _tabs.index == 0
                          ? 'No pending platform reports.'
                          : 'No resolved platform reports.',
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _reports;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: reports.length,
                  itemBuilder: (context, index) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: _reportCard(reports[index]),
                    ),
                  ),
                ),
              );
            },
          ),
  );

  Widget
  _buildSupportApplications() => FutureBuilder<List<FinancialSupportApplication>>(
    future: _supportApplications,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(WicchuIcons.arrowsClockwise),
            label: Text(context.trError(snapshot.error!)),
          ),
        );
      }
      final applications = snapshot.data ?? const [];
      if (applications.isEmpty) {
        return Center(
          child: Text(context.tr('No financial support applications.')),
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _supportApplications;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final item = applications[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.pageName ?? context.tr('Page'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${context.tr('Country')}: ${item.countryCode == 'OT' ? item.countryName : item.countryCode}',
                    ),
                    Text(
                      '${context.tr('Recipient type')}: ${context.tr(_recipientTypeLabel(item.recipientType))}',
                    ),
                    Text(
                      '${context.tr('Contact email')}: ${item.contactEmail}',
                    ),
                    const SizedBox(height: 10),
                    Text(item.purpose),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _saving.contains(item.id)
                              ? null
                              : () => _reviewSupport(item, false),
                          child: Text(context.tr('Reject')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saving.contains(item.id)
                              ? null
                              : () => _reviewSupport(item, true),
                          child: Text(context.tr('Approve')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  String _recipientTypeLabel(String value) => switch (value) {
    'organization' => 'Organization',
    'business' => 'Business',
    'community_project' => 'Community project',
    _ => 'Individual',
  };

  Future<void> _reviewSupport(
    FinancialSupportApplication application,
    bool approve,
  ) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(approve ? 'Approve application' : 'Reject application'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(
                approve
                    ? 'Approval does not enable payments. Recipient verification is still required.'
                    : 'Explain why the application was rejected.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(labelText: context.tr('Review note')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!approve && note.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text(context.tr('Confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving.add(application.id));
    try {
      await widget.repository.reviewFinancialSupportApplication(
        application.id,
        approve: approve,
        note: note.text,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      note.dispose();
      if (mounted) setState(() => _saving.remove(application.id));
    }
  }

  Widget _buildRewardRequests() => FutureBuilder<List<CommunityRewardRequest>>(
    future: _rewardRequests,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(WicchuIcons.arrowsClockwise),
            label: Text(context.trError(snapshot.error!)),
          ),
        );
      }
      final requests = snapshot.data ?? const [];
      if (requests.isEmpty) {
        return Center(child: Text(context.tr('No pending reward requests.')));
      }
      return RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _rewardRequests;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final country = request.countryCode == 'OT'
                ? request.countryName ?? request.countryCode
                : request.countryCode == 'ES'
                ? context.tr('Spain')
                : request.countryCode == 'EC'
                ? context.tr('Ecuador')
                : request.countryCode;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(request.contactEmail),
                    Text(
                      '${context.tr('Submitted')}: ${MaterialLocalizations.of(context).formatMediumDate(request.requestedAt.toLocal())}',
                    ),
                    if (request.note?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 10),
                      Text(request.note!),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _saving.contains(request.id)
                              ? null
                              : () => _reviewReward(request, false),
                          child: Text(context.tr('Reject')),
                        ),
                        FilledButton(
                          onPressed: _saving.contains(request.id)
                              ? null
                              : () => _reviewReward(request, true),
                          child: Text(context.tr('Approve')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _buildAnalytics() => FutureBuilder<PlatformAnalytics>(
    future: _analytics,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(WicchuIcons.arrowsClockwise),
            label: Text(context.trError(snapshot.error!)),
          ),
        );
      }
      final data = snapshot.data ?? const PlatformAnalytics();
      String money(int cents, String currency) => currency == 'USD'
          ? '\$${(cents / 100).toStringAsFixed(2)}'
          : '${(cents / 100).toStringAsFixed(2)} €';
      return RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _analytics;
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.tr('Platform growth'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AnalyticsCard(
                  label: 'Registered users',
                  value: '${data.registeredUsers}',
                ),
                _AnalyticsCard(
                  label: 'New registrations',
                  value: '${data.newRegistrations}',
                ),
                _AnalyticsCard(
                  label: 'Daily active users',
                  value: '${data.dailyActiveUsers}',
                ),
                _AnalyticsCard(
                  label: 'Weekly active users',
                  value: '${data.weeklyActiveUsers}',
                ),
                _AnalyticsCard(
                  label: 'Monthly active users',
                  value: '${data.monthlyActiveUsers}',
                ),
                _AnalyticsCard(
                  label: 'Monthly retention',
                  value: data.monthlyRetentionPercent == null
                      ? '—'
                      : '${data.monthlyRetentionPercent}%',
                ),
                _AnalyticsCard(
                  label: 'Active communities',
                  value: '${data.activeCommunities}',
                ),
                _AnalyticsCard(
                  label: 'Participating communities',
                  value: '${data.participatingCommunities}',
                ),
                _AnalyticsCard(
                  label: 'Pending reviews',
                  value: '${data.pendingReviews}',
                ),
              ],
            ),
            if (data.registrationsByLocation.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                context.tr('Registrations by location'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in data.registrationsByLocation)
                    _AnalyticsCard(
                      label: item.location,
                      value: '${item.users}',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(
              context.tr('Financial overview'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final item in data.currencySummary)
              Card(
                child: ListTile(
                  title: Text(
                    item.currency,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${context.tr('Pending')}: ${money(item.pendingCents, item.currency)} · ${context.tr('Approved')}: ${money(item.approvedCents, item.currency)} · ${context.tr('Paid')}: ${money(item.paidCents, item.currency)}',
                  ),
                  trailing: Text(
                    '${context.tr('Budget left')}\n${money(item.remainingBudgetCents, item.currency)}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              context.tr('Community performance'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (data.communityPerformance.isEmpty)
              Text(context.tr('No participating communities yet.'))
            else
              for (final item in data.communityPerformance)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${context.tr('Members')}: ${item.members} · ${context.tr('Monthly active members')}: ${item.monthlyActive}',
                        ),
                        Text(
                          '${context.tr('Publications')}: ${item.posts} · ${context.tr('Interactions')}: ${item.interactions} · ${context.tr('Contributors')}: ${item.contributors}',
                        ),
                        Text(
                          '${context.tr('New Wicchu users')}: ${item.newUsers} · ${context.tr('Active after 7 days')}: ${item.activeAfter7Days} · ${context.tr('Active after 30 days')}: ${item.activeAfter30Days}',
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );

  Future<void> _reviewReward(
    CommunityRewardRequest request,
    bool approve,
  ) async {
    final note = TextEditingController();
    var currency = request.countryCode == 'ES' ? 'EUR' : 'USD';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.tr(approve ? 'Approve request' : 'Reject request'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (approve)
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: InputDecoration(
                    labelText: context.tr('Currency'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => currency = value ?? currency),
                ),
              TextField(
                controller: note,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.tr('Review note'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr(approve ? 'Approve' : 'Reject')),
            ),
          ],
        ),
      ),
    );
    final reviewNote = note.text;
    note.dispose();
    if (!mounted) return;
    if (confirmed != true) return;
    if (!approve && reviewNote.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Add a reason before rejecting.'))),
      );
      return;
    }
    setState(() => _saving.add(request.id));
    try {
      await widget.repository.reviewCommunityRewardRequest(
        request.id,
        approve: approve,
        currency: currency,
        note: reviewNote,
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(request.id));
    }
  }

  Widget _buildRewardPayouts() => FutureBuilder<List<PlatformRewardPayout>>(
    future: _rewardPayouts,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(WicchuIcons.arrowsClockwise),
            label: Text(context.trError(snapshot.error!)),
          ),
        );
      }
      final payouts = snapshot.data ?? const [];
      if (payouts.isEmpty) {
        return Center(child: Text(context.tr('No payouts awaiting action.')));
      }
      return RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _rewardPayouts;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: payouts.length,
          itemBuilder: (context, index) {
            final payout = payouts[index];
            final amount = payout.currency == 'USD'
                ? '\$${(payout.rewardCents / 100).toStringAsFixed(2)}'
                : '${(payout.rewardCents / 100).toStringAsFixed(2)} €';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payout.communityName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(payout.contactEmail),
                    Text(
                      '${context.tr('Month')}: ${MaterialLocalizations.of(context).formatMonthYear(payout.periodStart.toLocal())}',
                    ),
                    Text('${context.tr('Amount')}: $amount'),
                    Text(
                      '${context.tr('Approved balance')}: ${payout.currency == 'USD' ? '\$' : ''}${(payout.availableBalanceCents / 100).toStringAsFixed(2)}${payout.currency == 'EUR' ? ' €' : ''}',
                    ),
                    Text(
                      '${context.tr('Status')}: ${context.tr(payout.status == 'pending_review' ? 'Pending review' : 'Approved')}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('Attributed users')}: ${payout.attributedJoins} · ${context.tr('New Wicchu users')}: ${payout.attributedNewUsers}',
                    ),
                    Text(
                      '${context.tr('Active after 7 days')}: ${payout.attributedActive7d} · ${context.tr('Active after 30 days')}: ${payout.attributedActive30d}',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: payout.status == 'approved'
                          ? [
                              FilledButton(
                                onPressed:
                                    _saving.contains(payout.id) ||
                                        payout.availableBalanceCents <
                                            payout.minimumPayoutCents
                                    ? null
                                    : () => _actOnPayout(payout, 'mark_paid'),
                                child: Text(context.tr('Mark paid')),
                              ),
                            ]
                          : [
                              OutlinedButton(
                                onPressed: _saving.contains(payout.id)
                                    ? null
                                    : () => _actOnPayout(payout, 'reject'),
                                child: Text(context.tr('Reject')),
                              ),
                              FilledButton(
                                onPressed: _saving.contains(payout.id)
                                    ? null
                                    : () => _actOnPayout(payout, 'approve'),
                                child: Text(context.tr('Approve')),
                              ),
                            ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Future<void> _actOnPayout(PlatformRewardPayout payout, String action) async {
    String? note;
    if (action == 'reject') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('Reject payout')),
          content: TextField(
            controller: controller,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: context.tr('Reason')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(context.tr('Reject')),
            ),
          ],
        ),
      );
      controller.dispose();
      if (!mounted || note == null) return;
      if (note.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Add a reason before rejecting.'))),
        );
        return;
      }
    }
    setState(() => _saving.add(payout.id));
    try {
      await widget.repository.reviewPlatformRewardPayout(
        payout.id,
        action: action,
        note: note,
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(payout.id));
    }
  }

  Widget _reportCard(PlatformReport report) {
    final pending = report.status == 'pending';
    final isBanAppeal = report.evidence['kind'] == 'ban_appeal';
    final isSafetyRequest = report.evidence['kind'] == 'manager_safety_request';
    final targetType = isSafetyRequest
        ? 'Safety request'
        : isBanAppeal
        ? 'Ban appeal'
        : switch (report.targetType) {
            PlatformReportTargetType.community => 'Community',
            PlatformReportTargetType.communityAdmin => 'Community admin',
            PlatformReportTargetType.message => 'Direct message',
            PlatformReportTargetType.post => 'Personal publication',
            PlatformReportTargetType.comment => 'Comment',
            PlatformReportTargetType.user => 'User',
          };
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(context.tr(targetType))),
                Chip(label: Text(context.tr(_categoryLabel(report.category)))),
                Chip(label: Text(context.tr(report.status))),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              report.targetName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (report.communityId.isNotEmpty)
              Text('${context.tr('Community')}: ${report.communityName}'),
            Text('${context.tr('Reporter')}: ${report.reporterName}'),
            Text(
              '${context.tr('Submitted')}: ${MaterialLocalizations.of(context).formatMediumDate(report.createdAt.toLocal())}',
            ),
            const Divider(height: 28),
            Text(report.reason),
            if (report.evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.tr('Evidence snapshot')),
                children: [SelectableText(report.evidence.toString())],
              ),
            ],
            if (!pending && report.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              Text(
                context.tr('Resolution'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final action in report.actions) ...[
                Text(
                  context.tr(_actionLabel(action.action)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('${context.tr('Moderator')}: ${action.moderatorName}'),
                Text(
                  '${context.tr('Resolved')}: ${MaterialLocalizations.of(context).formatMediumDate(action.createdAt.toLocal())}',
                ),
                if (action.note.isNotEmpty)
                  Text('${context.tr('Note')}: ${action.note}'),
                const SizedBox(height: 8),
              ],
            ],
            if (pending) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _saving.contains(report.id)
                        ? null
                        : () => _decide(report, 'dismiss'),
                    child: Text(
                      context.tr(
                        isSafetyRequest ? 'Dismiss request' : 'Dismiss report',
                      ),
                    ),
                  ),
                  if (isBanAppeal)
                    FilledButton.tonal(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'restore_membership'),
                      child: Text(context.tr('Restore membership')),
                    ),
                  if (isSafetyRequest)
                    FilledButton.tonal(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'close_request'),
                      child: Text(context.tr('Resolve request')),
                    ),
                  if (report.targetType ==
                      PlatformReportTargetType.communityAdmin) ...[
                    OutlinedButton(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'warn'),
                      child: Text(context.tr('Warn admin')),
                    ),
                    FilledButton.tonal(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'remove_admin_role'),
                      child: Text(context.tr('Remove admin role')),
                    ),
                    FilledButton(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'suspend_user'),
                      child: Text(context.tr('Suspend user')),
                    ),
                  ],
                  if (report.targetType ==
                      PlatformReportTargetType.message) ...[
                    OutlinedButton(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'warn'),
                      child: Text(context.tr('Warn user')),
                    ),
                    FilledButton.tonal(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'remove_message'),
                      child: Text(context.tr('Remove message')),
                    ),
                    FilledButton(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'suspend_user'),
                      child: Text(context.tr('Suspend user')),
                    ),
                  ],
                  if ({
                    PlatformReportTargetType.post,
                    PlatformReportTargetType.comment,
                    PlatformReportTargetType.user,
                  }.contains(report.targetType)) ...[
                    OutlinedButton(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'warn'),
                      child: Text(context.tr('Warn user')),
                    ),
                    if (report.targetType != PlatformReportTargetType.user)
                      FilledButton.tonal(
                        onPressed: _saving.contains(report.id)
                            ? null
                            : () => _decide(report, 'remove_content'),
                        child: Text(context.tr('Remove content')),
                      ),
                    FilledButton(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'suspend_user'),
                      child: Text(context.tr('Suspend user')),
                    ),
                  ],
                  if (!isBanAppeal &&
                      report.communityId.isNotEmpty &&
                      {
                        PlatformReportTargetType.community,
                        PlatformReportTargetType.communityAdmin,
                      }.contains(report.targetType))
                    FilledButton(
                      onPressed: _saving.contains(report.id)
                          ? null
                          : () => _decide(report, 'suspend_community'),
                      child: Text(context.tr('Suspend community')),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _decide(PlatformReport report, String action) async {
    var note = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr(_actionLabel(action))),
        content: TextField(
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          onChanged: (value) => note = value,
          decoration: InputDecoration(
            labelText: dialogContext.tr('Internal note or warning message'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving.add(report.id));
    try {
      await widget.repository.decidePlatformReport(
        report.id,
        action: action,
        note: note,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(report.id));
    }
  }

  String _categoryLabel(String category) => switch (category) {
    'spam' => 'Spam',
    'harassment' => 'Harassment',
    'hate' => 'Hate speech',
    'violence' => 'Violence',
    'sexual' => 'Sexual content',
    'child_safety' => 'Child safety',
    'self_harm' => 'Self-harm',
    'scam' => 'Scam or fraud',
    'illegal' => 'Illegal activity',
    _ => 'Other concern',
  };

  String _actionLabel(String action) => switch (action) {
    'dismiss' => 'Dismiss report',
    'warn' => 'Warn user',
    'remove_content' => 'Remove content',
    'remove_message' => 'Remove message',
    'restore_membership' => 'Restore membership',
    'close_request' => 'Resolve request',
    'remove_admin_role' => 'Remove admin role',
    'suspend_user' => 'Suspend user',
    _ => 'Suspend community',
  };
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(context.tr(label)),
          ],
        ),
      ),
    ),
  );
}
