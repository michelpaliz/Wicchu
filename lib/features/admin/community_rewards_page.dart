import 'package:flutter/material.dart';
import 'package:wicchu/theme/wicchu_icons.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class CommunityRewardsPage extends StatefulWidget {
  const CommunityRewardsPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityRewardsPage> createState() => _CommunityRewardsPageState();
}

class _CommunityRewardsPageState extends State<CommunityRewardsPage> {
  late Future<CommunityInsights> _future = _load();

  Future<CommunityInsights> _load() =>
      widget.repository.getCommunityInsights(widget.community.id);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Community rewards'))),
    body: FutureBuilder<CommunityInsights>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: _refresh,
              child: Text(context.tr('Retry')),
            ),
          );
        }
        final insights = snapshot.data!;
        final enrollment = insights.monetization.enrollment;
        if (!enrollment.requested || enrollment.status == 'rejected') {
          return _RewardRequestForm(
            canRequest: widget.community.myRole == CommunityRole.owner,
            reviewNote: enrollment.reviewNote,
            onSubmit:
                ({
                  required countryCode,
                  countryName,
                  required contactEmail,
                  note,
                }) async {
                  await widget.repository.requestCommunityRewards(
                    widget.community.id,
                    countryCode: countryCode,
                    countryName: countryName,
                    contactEmail: contactEmail,
                    note: note,
                  );
                  await _refresh();
                },
          );
        }
        if (enrollment.status == 'pending') {
          return _RewardRequestPending(enrollment: enrollment);
        }
        if (!insights.monetization.enrollment.accepted) {
          return _RewardEnrollment(
            canAccept: widget.community.myRole == CommunityRole.owner,
            countryCode: enrollment.countryCode ?? 'ES',
            onAccept: (countryCode) async {
              await widget.repository.acceptCommunityRewardTerms(
                widget.community.id,
                countryCode: countryCode,
              );
              await _refresh();
            },
          );
        }
        return _RewardDetails(insights: insights, onRefresh: _refresh);
      },
    ),
  );
}

class _RewardRequestForm extends StatefulWidget {
  const _RewardRequestForm({
    required this.canRequest,
    required this.onSubmit,
    this.reviewNote,
  });

  final bool canRequest;
  final String? reviewNote;
  final Future<void> Function({
    required String countryCode,
    String? countryName,
    required String contactEmail,
    String? note,
  })
  onSubmit;

  @override
  State<_RewardRequestForm> createState() => _RewardRequestFormState();
}

class _RewardRequestFormState extends State<_RewardRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _country = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  String _countryCode = 'ES';
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _country.dispose();
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        context.tr('Request Community Rewards'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr(
          'Tell Wicchu where you are based. We will review availability and contact you.',
        ),
      ),
      if (widget.reviewNote?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        Text(
          widget.reviewNote!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 18),
      Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _countryCode,
              decoration: InputDecoration(labelText: context.tr('Country')),
              items: [
                DropdownMenuItem(value: 'ES', child: Text(context.tr('Spain'))),
                DropdownMenuItem(
                  value: 'EC',
                  child: Text(context.tr('Ecuador')),
                ),
                DropdownMenuItem(
                  value: 'OT',
                  child: Text(context.tr('Another country')),
                ),
              ],
              onChanged: widget.canRequest && !_saving
                  ? (value) => setState(() => _countryCode = value ?? 'ES')
                  : null,
            ),
            if (_countryCode == 'OT') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _country,
                decoration: InputDecoration(
                  labelText: context.tr('Country name'),
                ),
                validator: (value) => value?.trim().isEmpty ?? true
                    ? context.tr('Required')
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.tr('Contact email'),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                return email.contains('@')
                    ? null
                    : context.tr('Enter a valid email');
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr('Message (optional)'),
              ),
            ),
          ],
        ),
      ),
      if (!widget.canRequest)
        Text(context.tr('Only the community owner can send this request.')),
      if (_error != null)
        Text(
          context.trError(_error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 12),
      if (widget.canRequest)
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(context.tr(_saving ? 'Sending…' : 'Send request')),
        ),
    ],
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        countryCode: _countryCode,
        countryName: _countryCode == 'OT' ? _country.text.trim() : null,
        contactEmail: _email.text.trim(),
        note: _note.text.trim(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RewardRequestPending extends StatelessWidget {
  const _RewardRequestPending({required this.enrollment});
  final CommunityRewardEnrollment enrollment;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(WicchuIcons.clock, size: 48),
          const SizedBox(height: 14),
          Text(
            context.tr('Request under review'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            enrollment.contactEmail?.isNotEmpty == true
                ? context.tr(
                    'Wicchu will contact you at {email} after reviewing availability in your country.',
                    {'email': enrollment.contactEmail!},
                  )
                : context.tr(
                    'Wicchu will contact the community owner after reviewing availability.',
                  ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _RewardEnrollment extends StatefulWidget {
  const _RewardEnrollment({
    required this.canAccept,
    required this.countryCode,
    required this.onAccept,
  });

  final bool canAccept;
  final String countryCode;
  final Future<void> Function(String countryCode) onAccept;

  @override
  State<_RewardEnrollment> createState() => _RewardEnrollmentState();
}

class _RewardEnrollmentState extends State<_RewardEnrollment> {
  bool _accepted = false;
  bool _saving = false;
  Object? _error;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        context.tr('Join the Community Rewards pilot'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr(
          'Your request was approved. Review and accept the terms to join.',
        ),
      ),
      const SizedBox(height: 22),
      Text(
        context.tr('Before you join'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      for (final item in [
        'Rewards are reviewed and are not guaranteed.',
        'Spam, duplicate accounts and artificial activity do not count.',
        'Approved rewards are paid after the monthly review.',
        'Rewards may be taxable income in your country.',
        'Wicchu may change future reward amounts with advance notice.',
        'You can appeal a rejected monthly reward.',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(WicchuIcons.check, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(context.tr(item))),
            ],
          ),
        ),
      const SizedBox(height: 8),
      if (widget.canAccept)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _accepted,
          onChanged: _saving
              ? null
              : (value) => setState(() => _accepted = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            context.tr(
              'I understand and accept the Community Rewards pilot terms.',
            ),
          ),
        )
      else
        Text(
          context.tr('Only the community owner can accept these terms.'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          context.trError(_error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 12),
      if (widget.canAccept)
        FilledButton(
          onPressed: !_accepted || _saving ? null : _submit,
          child: Text(
            context.tr(_saving ? 'Saving…' : 'Accept and join pilot'),
          ),
        ),
    ],
  );

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAccept(widget.countryCode);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RewardDetails extends StatelessWidget {
  const _RewardDetails({required this.insights, required this.onRefresh});

  final CommunityInsights insights;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final reward = insights.monetization;
    final tier = reward.nextTier ?? reward.currentTier;
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Current evaluation period'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('{days} days remaining', {
                      'days': '${reward.daysRemaining}',
                    }),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reward.currentTier == null
                        ? context.tr('No reward unlocked yet')
                        : context.tr('Estimated reward: {amount} per month', {
                            'amount': _money(
                              reward.currentTier!.monthlyRewardCents,
                              reward.currency,
                            ),
                          }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(WicchuIcons.currencyDollar),
              title: Text(context.tr('Approved balance')),
              subtitle: Text(
                reward.availableBalanceCents >= reward.minimumPayoutCents
                    ? context.tr('Ready for manual payment')
                    : context.tr('{amount} remaining until payout', {
                        'amount': _money(
                          reward.minimumPayoutCents -
                              reward.availableBalanceCents,
                          reward.currency,
                        ),
                      }),
              ),
              trailing: Text(
                _money(reward.availableBalanceCents, reward.currency),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (tier != null) ...[
            _heading(context, 'Progress toward {level}', {
              'level': _tierName(context, tier.id),
            }),
            _Metric(
              label: 'Members',
              explanation:
                  'Active accounts that currently belong to this community.',
              value: insights.totalMembers,
              target: tier.memberTarget,
            ),
            _Metric(
              label: 'Monthly active members',
              explanation:
                  'Unique members who visited or participated during the previous 30 days.',
              value: insights.monthlyActiveUsers,
              target: tier.monthlyActiveTarget,
            ),
            _Metric(
              label: 'Useful posts in 30 days',
              explanation:
                  'Published community posts; removed or rejected content is excluded.',
              value: insights.posts30d,
              target: tier.postsTarget,
            ),
            _Metric(
              label: 'Meaningful interactions in 30 days',
              explanation:
                  'Published comments and reactions from community activity.',
              value: insights.interactions30d,
              target: tier.interactionsTarget,
            ),
            _Metric(
              label: 'Unique contributors in 30 days',
              explanation:
                  'Different non-admin members who published, commented or voted in a poll.',
              value: insights.uniqueContributors30d,
              target: tier.contributorsTarget,
            ),
            if (tier.retentionTargetPercent > 0)
              insights.retentionDataAvailable
                  ? _Metric(
                      label: 'Monthly member retention',
                      explanation:
                          'Members present before the UTC calendar month who were active during that month.',
                      value: insights.monthlyRetentionRate,
                      target: tier.retentionTargetPercent,
                      suffix: '%',
                    )
                  : Card(
                      child: ListTile(
                        title: Text(context.tr('Monthly member retention')),
                        subtitle: Text(context.tr('Not enough retention data')),
                      ),
                    ),
          ],
          _heading(context, 'Eligibility and payment'),
          _StatusRow(
            icon: reward.goodStanding
                ? WicchuIcons.shieldCheck
                : WicchuIcons.shieldWarning,
            label: 'Community status',
            value: reward.goodStanding ? 'Good standing' : 'Restricted',
            success: reward.goodStanding,
          ),
          const SizedBox(height: 10),
          _StatusRow(
            icon: WicchuIcons.currencyDollar,
            label: 'Payment setup',
            value: reward.payoutSetupComplete ? 'Complete' : 'Required',
            success: reward.payoutSetupComplete,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Results are reviewed after the month ends. Spam, duplicate accounts and artificial engagement are excluded.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _heading(context, 'Previous monthly results'),
          if (reward.history.isEmpty)
            Text(context.tr('No completed evaluation periods yet.'))
          else
            for (final item in reward.history) _HistoryTile(item: item),
        ],
      ),
    );
  }

  static Widget _heading(
    BuildContext context,
    String label, [
    Map<String, String> values = const {},
  ]) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      context.tr(label, values),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.explanation,
    required this.value,
    required this.target,
    this.suffix = '',
  });

  final String label;
  final String explanation;
  final num value;
  final num target;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 1.0 : (value / target).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(label),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${_number(value)}$suffix / ${_number(target)}$suffix'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              context.tr(explanation),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.success,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool success;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: success ? Colors.green : Colors.orange),
      const SizedBox(width: 10),
      Expanded(child: Text(context.tr(label))),
      Text(
        context.tr(value),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final CommunityRewardEvaluation item;

  @override
  Widget build(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    final title = dates.formatMonthYear(item.periodStart.toLocal());
    final status = switch (item.status) {
      'pending_review' => 'Pending review',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'paid' => 'Paid',
      _ => 'Not qualified',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(status)),
            if (item.paidAt != null)
              Text(
                '${context.tr('Paid on')} ${dates.formatMediumDate(item.paidAt!.toLocal())}',
              ),
            if (item.reviewNote?.isNotEmpty ?? false) Text(item.reviewNote!),
          ],
        ),
        trailing: Text(
          item.rewardCents > 0 ? _money(item.rewardCents, item.currency) : '—',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

String _tierName(BuildContext context, String id) => context.tr(switch (id) {
  'active' => 'Active',
  'growing' => 'Growing',
  'high_impact' => 'High Impact',
  _ => id,
});

String _money(int cents, String currency) {
  final euros = cents / 100;
  final amount = euros == euros.roundToDouble()
      ? euros.toInt().toString()
      : euros.toStringAsFixed(2);
  return currency == 'USD' ? '\$$amount' : '$amount €';
}

String _number(num value) => value is double && value % 1 != 0
    ? value.toStringAsFixed(1)
    : value.toInt().toString();
