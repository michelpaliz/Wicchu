import '../../widgets/wicchu_list_tile.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class PlatformModerationPage extends StatefulWidget {
  const PlatformModerationPage({
    super.key,
    required this.repository,
    this.initialTab = 0,
  }) : assert(initialTab >= 0 && initialTab < 6);

  final CommunityRepository repository;
  final int initialTab;

  @override
  State<PlatformModerationPage> createState() => _PlatformModerationPageState();
}

class _PlatformModerationPageState extends State<PlatformModerationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 6, initialIndex: widget.initialTab, vsync: this)
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.trError(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(WicchuIcons.arrowsClockwise),
                  label: Text(context.tr('Retry')),
                ),
              ],
            ),
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
            return WicchuListTile.custom(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.pageName ?? context.tr('Page'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${context.tr('Country')}: ${item.countryCode == 'OT' ? item.countryName : item.countryCode}',
                    ),
                    Text(
                      '${context.tr('Recipient type')}: ${context.tr(_recipientTypeLabel(item.recipientType))}',
                    ),
                    SelectableText(
                      '${context.tr('Contact email')}: ${item.contactEmail}',
                    ),
                    const SizedBox(height: 10),
                    Text(item.purpose),
                    const SizedBox(height: 12),
                    if (_saving.contains(item.id))
                      const LinearProgressIndicator(),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _saving.contains(item.id)
                              ? null
                              : () => _reviewSupport(item, false),
                          child: Text(context.tr('Reject')),
                        ),
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
    if (_saving.contains(application.id)) return;
    var reviewNote = "";
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(approve ? 'Approve application' : 'Reject application'),
        ),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
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
              TextFormField(
                validator: (value) =>
                    !approve && (value?.trim().isEmpty ?? true)
                    ? context.tr('Explain why the application was rejected.')
                    : null,
                onChanged: (value) => reviewNote = value,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.tr('Review note'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text(
              context.tr(
                approve ? 'Approve application' : 'Reject application',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _saving.add(application.id));
    try {
      await widget.repository.reviewFinancialSupportApplication(
        application.id,
        approve: approve,
        note: reviewNote.trim(),
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Reward request'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ModerationInfoRow(
                      icon: WicchuIcons.mapPin,
                      label: context.tr('Country'),
                      value: country,
                    ),
                    _ModerationInfoRow(
                      icon: WicchuIcons.envelope,
                      label: context.tr('Contact email'),
                      value: request.contactEmail,
                    ),
                    _ModerationInfoRow(
                      icon: WicchuIcons.calendarBlank,
                      label: context.tr('Submitted'),
                      value: MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(request.requestedAt.toLocal()),
                    ),
                    if (request.note?.isNotEmpty ?? false) ...[
                      const Divider(height: 24),
                      Text(request.note!),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving.contains(request.id)
                                ? null
                                : () => _reviewReward(request, false),
                            child: Text(context.tr('Reject')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving.contains(request.id)
                                ? null
                                : () => _reviewReward(request, true),
                            child: Text(context.tr('Approve')),
                          ),
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
            _AnalyticsGrid(
              items: [
                ('Registered users', '${data.registeredUsers}'),
                ('New registrations', '${data.newRegistrations}'),
                ('Daily active users', '${data.dailyActiveUsers}'),
                ('Weekly active users', '${data.weeklyActiveUsers}'),
                ('Monthly active users', '${data.monthlyActiveUsers}'),
                (
                  'Monthly retention',
                  data.monthlyRetentionPercent == null
                      ? '—'
                      : '${data.monthlyRetentionPercent}%',
                ),
                ('Active communities', '${data.activeCommunities}'),
                (
                  'Participating communities',
                  '${data.participatingCommunities}',
                ),
                ('Pending reviews', '${data.pendingReviews}'),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Translation usage'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (!data.translationAnalyticsAvailable)
              Text(
                context.tr('Translation analytics are temporarily unavailable'),
              )
            else
              _AnalyticsGrid(
                items: [
                  ('Translation requests (30d)', '${data.translationRequests}'),
                  ('Translation errors (30d)', '${data.translationErrors}'),
                  (
                    'Average translation latency',
                    '${data.translationAverageLatencyMs.round()} ms',
                  ),
                  (
                    'Estimated translation cost (30d)',
                    '\$${data.translationEstimatedCostUsd.toStringAsFixed(2)}',
                  ),
                  (
                    'Monthly translation budget',
                    '\$${data.translationMonthlyBudgetUsedUsd.toStringAsFixed(2)} / \$${data.translationMonthlyBudgetLimitUsd.toStringAsFixed(2)}',
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
              _AnalyticsGrid(
                items: [
                  for (final item in data.registrationsByLocation)
                    (item.location, '${item.users}'),
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
    var reviewNote = '';
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
                maxLength: 500,
                maxLines: 3,
                onChanged: (value) => setDialogState(() => reviewNote = value),
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
              onPressed: approve || reviewNote.trim().isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(context.tr(approve ? 'Approve' : 'Reject')),
            ),
          ],
        ),
      ),
    );
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            payout.communityName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _StatusPill(
                          label: context.tr(
                            payout.status == 'pending_review'
                                ? 'Pending review'
                                : 'Approved',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      amount,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _ModerationInfoRow(
                      icon: WicchuIcons.envelope,
                      label: context.tr('Contact email'),
                      value: payout.contactEmail,
                    ),
                    _ModerationInfoRow(
                      icon: WicchuIcons.calendarBlank,
                      label: context.tr('Month'),
                      value: MaterialLocalizations.of(
                        context,
                      ).formatMonthYear(payout.periodStart.toLocal()),
                    ),
                    _ModerationInfoRow(
                      icon: WicchuIcons.money,
                      label: context.tr('Approved balance'),
                      value:
                          '${payout.currency == 'USD' ? '\$' : ''}${(payout.availableBalanceCents / 100).toStringAsFixed(2)}${payout.currency == 'EUR' ? ' €' : ''}',
                    ),
                    const Divider(height: 24),
                    Text(
                      context.tr('Attributed activity'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CompactMetrics(
                      items: [
                        (
                          context.tr('Attributed users'),
                          payout.attributedJoins,
                        ),
                        (
                          context.tr('New Wicchu users'),
                          payout.attributedNewUsers,
                        ),
                        (
                          context.tr('Active after 7 days'),
                          payout.attributedActive7d,
                        ),
                        (
                          context.tr('Active after 30 days'),
                          payout.attributedActive30d,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: payout.status == 'approved'
                          ? [
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      _saving.contains(payout.id) ||
                                          payout.availableBalanceCents <
                                              payout.minimumPayoutCents
                                      ? null
                                      : () => _actOnPayout(payout, 'mark_paid'),
                                  child: Text(context.tr('Mark paid')),
                                ),
                              ),
                            ]
                          : [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving.contains(payout.id)
                                      ? null
                                      : () => _actOnPayout(payout, 'reject'),
                                  child: Text(context.tr('Reject')),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving.contains(payout.id)
                                      ? null
                                      : () => _actOnPayout(payout, 'approve'),
                                  child: Text(context.tr('Approve')),
                                ),
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
      var rejectionReason = '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(context.tr('Reject payout')),
            content: TextField(
              maxLength: 500,
              maxLines: 3,
              onChanged: (value) =>
                  setDialogState(() => rejectionReason = value),
              decoration: InputDecoration(labelText: context.tr('Reason')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: rejectionReason.trim().isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('Reject')),
              ),
            ],
          ),
        ),
      );
      if (!mounted || confirmed != true) return;
      note = rejectionReason.trim();
      if (note.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Add a reason before rejecting.'))),
        );
        return;
      }
    } else {
      final amount = payout.currency == 'USD'
          ? '\$${(payout.rewardCents / 100).toStringAsFixed(2)}'
          : '${(payout.rewardCents / 100).toStringAsFixed(2)} €';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            dialogContext.tr(
              action == 'mark_paid' ? 'Mark payout as paid' : 'Approve payout',
            ),
          ),
          content: Text(
            dialogContext.tr('Confirm {amount} for {community}.', {
              'amount': amount,
              'community': payout.communityName,
            }),
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
      if (!mounted || confirmed != true) return;
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

class _ModerationInfoRow extends StatelessWidget {
  const _ModerationInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 17,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _CompactMetrics extends StatelessWidget {
  const _CompactMetrics({required this.items});

  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 8.0;
      final width = (constraints.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: 8,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.$2}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _AnalyticsGrid extends StatelessWidget {
  const _AnalyticsGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      final columns = constraints.maxWidth >= 340 ? 2 : 1;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final item in items)
            _AnalyticsCard(label: item.$1, value: item.$2, width: width),
        ],
      );
    },
  );
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
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
