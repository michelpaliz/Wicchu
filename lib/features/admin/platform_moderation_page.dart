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
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) _reload();
    });
  late Future<List<PlatformReport>> _reports = _load();
  final Set<String> _saving = {};

  Future<List<PlatformReport>> _load() =>
      widget.repository.listPlatformReports(resolved: _tabs.index == 1);

  void _reload() => setState(() => _reports = _load());

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
        tabs: [
          Tab(text: context.tr('Pending')),
          Tab(text: context.tr('Resolved')),
        ],
      ),
    ),
    body: FutureBuilder<List<PlatformReport>>(
      future: _reports,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
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
            if (report.targetType != PlatformReportTargetType.message)
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
                  if (!isBanAppeal &&
                      report.targetType != PlatformReportTargetType.message)
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
    'remove_message' => 'Remove message',
    'restore_membership' => 'Restore membership',
    'close_request' => 'Resolve request',
    'remove_admin_role' => 'Remove admin role',
    'suspend_user' => 'Suspend user',
    _ => 'Suspend community',
  };
}
