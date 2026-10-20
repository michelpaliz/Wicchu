import 'package:flutter/material.dart';

import '../../data/authenticated_api_client.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import 'pending_posts_page.dart';

typedef _LocalNewsData = ({
  LocalNewsSettings settings,
  List<LocalNewsSource> sources,
  List<CommunityCategory> categories,
  List<LocalNewsArticle> articles,
});

class LocalNewsSettingsPage extends StatefulWidget {
  const LocalNewsSettingsPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<LocalNewsSettingsPage> createState() => _LocalNewsSettingsPageState();
}

class _LocalNewsSettingsPageState extends State<LocalNewsSettingsPage> {
  late Future<_LocalNewsData> _data = _load();
  LocalNewsSettings? _settings;
  Set<String> _sourceIds = {};
  Set<String> _categoryIds = {};
  String _language = 'es';
  String _approvalMode = 'manual';
  bool _enabled = false;
  bool _saving = false;
  bool _running = false;

  Future<_LocalNewsData> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.getLocalNewsSettings(widget.community.id),
      widget.repository.listLocalNewsSources(),
      widget.repository.listCategories(widget.community.id),
      widget.repository.listLocalNewsArticles(widget.community.id),
    ]);
    final data = (
      settings: values[0] as LocalNewsSettings,
      sources: values[1] as List<LocalNewsSource>,
      categories: values[2] as List<CommunityCategory>,
      articles: values[3] as List<LocalNewsArticle>,
    );
    _apply(data.settings);
    return data;
  }

  void _reload() => setState(() {
    _data = _load();
  });

  void _apply(LocalNewsSettings settings) {
    _settings = settings;
    _enabled = settings.enabled;
    _sourceIds = settings.sourceIds.toSet();
    _categoryIds = settings.categoryIds.toSet();
    _language = settings.language;
    _approvalMode = settings.approvalMode;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_enabled) {
      final data = await _data;
      if (!mounted) return;
      if (data.sources.isEmpty) {
        _showMessage(context.tr('Wicchu must approve a news source before automated news can be enabled.'));
        return;
      }
      if (_sourceIds.isEmpty || !_sourceIds.every((id) => data.sources.any((source) => source.id == id))) {
        _showMessage(context.tr('Select an available approved news source.'));
        return;
      }
      if (_categoryIds.isEmpty || !_categoryIds.every((id) => data.categories.any((category) => category.id == id))) {
        _showMessage(context.tr('Select an available news category.'));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await widget.repository.updateLocalNewsSettings(
        widget.community.id,
        enabled: _enabled,
        sourceIds: _sourceIds.toList(),
        categoryIds: _categoryIds.toList(),
        language: _language,
        approvalMode: _approvalMode,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _data = _load();
      });
      _showMessage(context.tr('Local News settings saved.'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(context.trError(error));
    }
  }

  Future<void> _runNow() async {
    setState(() => _running = true);
    try {
      final result = await widget.repository.runLocalNewsNow(
        widget.community.id,
      );
      if (!mounted) return;
      _showMessage(
        context.tr('Processed {count} news articles.', {
          'count': '${result.processed}',
        }),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(context.trError(error));
    } finally {
      // The run may have changed the dashboard even when it failed.
      if (mounted) {
        setState(() {
          _running = false;
          _data = _load();
        });
      }
    }
  }

  Future<void> _reviewPending() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PendingPostsPage(
          community: widget.community,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Automated news'))),
    body: FutureBuilder<_LocalNewsData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _settings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && _settings == null) {
          final error = snapshot.error;
          if (error is ApiException && error.statusCode == 403) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    'Automated news is not available for this community.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Center(
            child: FilledButton(
              onPressed: _reload,
              child: Text(context.tr('Retry')),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _data;
          },
          child: _settingsView(data),
        );
      },
    ),
  );

  Widget _settingsView(_LocalNewsData data) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    children: [
      if (data.settings.dashboard != null)
        _LocalNewsDashboardCard(
          dashboard: data.settings.dashboard!,
          onReviewPending: _reviewPending,
          onRefresh: _reload,
        ),
      const SizedBox(height: 16),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.tr('Enable automated news')),
        subtitle: Text(
          context.tr(
            'The scheduler will check for relevant articles automatically.',
          ),
        ),
        value: _enabled,
        onChanged: (value) {
          if (value && data.sources.isEmpty) {
            _showMessage(context.tr('Wicchu must approve a news source before automated news can be enabled.'));
            return;
          }
          setState(() => _enabled = value);
        },
      ),
      const Divider(),
      _title('News language'),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'es', label: Text(context.tr('Spanish'))),
          ButtonSegment(value: 'en', label: Text(context.tr('English'))),
        ],
        selected: {_language},
        onSelectionChanged: (values) =>
            setState(() => _language = values.first),
      ),
      const SizedBox(height: 22),
      _title('Publication approval'),
      RadioGroup<String>(
        groupValue: _approvalMode,
        onChanged: (value) => setState(() => _approvalMode = value ?? 'manual'),
        child: Column(
          children: [
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'manual',
              title: Text(context.tr('Review before publishing')),
              subtitle: Text(context.tr('Recommended for every new source.')),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'automatic',
              title: Text(context.tr('Publish automatically')),
              subtitle: Text(
                context.tr(
                  'Only sources trusted and authorized by Wicchu can publish automatically.',
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _title('Approved sources'),
      if (data.sources.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Wicchu must approve a news source before automated news can be enabled.')),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(WicchuIcons.arrowsClockwise),
                  label: Text(context.tr('Refresh approved sources')),
                ),
              ],
            ),
          ),
        ),
      for (final source in data.sources)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _sourceIds.contains(source.id),
          title: Text(source.name),
          subtitle: Text(
            context.tr(
              source.authorizedForAutoPublish
                  ? 'Trusted for automatic publishing'
                  : 'Review required',
            ),
          ),
          onChanged: (checked) => setState(() {
            checked == true
                ? _sourceIds.add(source.id)
                : _sourceIds.remove(source.id);
          }),
        ),
      const SizedBox(height: 12),
      _title('News categories'),
      Text(
        context.tr(
          'The AI will only use the categories you select. It never creates new categories.',
        ),
      ),
      for (final category in data.categories)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _categoryIds.contains(category.id),
          title: Text(category.name),
          onChanged: (checked) => setState(() {
            checked == true
                ? _categoryIds.add(category.id)
                : _categoryIds.remove(category.id);
          }),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(WicchuIcons.floppyDisk),
        label: Text(context.tr('Save settings')),
      ),
      if (_settings?.enabled == true) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _running ? null : _runNow,
          icon: _running
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(WicchuIcons.arrowsClockwise),
          label: Text(context.tr('Check for news now')),
        ),
      ],
      if (data.articles.isNotEmpty) ...[
        const SizedBox(height: 24),
        _title('Recent news activity'),
        for (final article in data.articles.take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_statusIcon(article.status)),
            title: Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(context.tr(_statusLabel(article.status))),
          ),
      ],
    ],
  );

  Widget _title(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      context.tr(value),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  IconData _statusIcon(String status) => switch (status) {
    'published' => WicchuIcons.checkCircle,
    'pending_approval' => WicchuIcons.clock,
    'error' => WicchuIcons.shieldWarning,
    'skipped' => WicchuIcons.prohibit,
    _ => WicchuIcons.article,
  };

  String _statusLabel(String status) => switch (status) {
    'published' => 'Published',
    'pending_approval' => 'Waiting for review',
    'error' => 'Processing error',
    'skipped' => 'Not relevant',
    'processing' => 'Processing',
    _ => 'Collected',
  };
}

/// Compact operational summary. All times are shown in the device's timezone.
class _LocalNewsDashboardCard extends StatelessWidget {
  const _LocalNewsDashboardCard({
    required this.dashboard,
    required this.onReviewPending,
    required this.onRefresh,
  });

  final LocalNewsDashboard dashboard;
  final VoidCallback onReviewPending;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final run = dashboard.lastRun;
    final (IconData icon, Color tone) = switch (dashboard.status) {
      'collecting' => (WicchuIcons.arrowsClockwise, colors.primary),
      'awaiting_approval' => (WicchuIcons.hourglass, colors.tertiary),
      'daily_limit_reached' => (WicchuIcons.clock, colors.secondary),
      'configuration_needed' => (WicchuIcons.gearSix, colors.error),
      'paused' => (WicchuIcons.pause, colors.outline),
      'error' => (WicchuIcons.warningCircle, colors.error),
      _ => (WicchuIcons.calendarBlank, colors.primary),
    };
    final waitingToday = dashboard.todayUsed - dashboard.publishedToday;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tone),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(_statusTitle(dashboard.status)),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Refresh'),
                  onPressed: onRefresh,
                  icon: const Icon(WicchuIcons.arrowsClockwise, size: 20),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                context.tr(_statusDetail(dashboard)),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            _Row(
              icon: dashboard.enabled
                  ? WicchuIcons.playFill
                  : WicchuIcons.pause,
              label: context.tr('Automated news'),
              value: context.tr(dashboard.enabled ? 'Enabled' : 'Disabled'),
            ),
            _Row(
              icon: WicchuIcons.calendarBlank,
              label: context.tr('Next review'),
              value: dashboard.nextCollectionAt == null
                  ? context.tr('Next review not available')
                  : _dateTime(context, dashboard.nextCollectionAt!),
            ),
            _Row(
              icon: WicchuIcons.clockCounterClockwise,
              label: context.tr('Last review'),
              value: run == null
                  ? context.tr('Not run yet')
                  : '${context.tr(_runLabel(run))} · ${_dateTime(context, run.finishedAt)}',
            ),
            _Row(
              icon: WicchuIcons.hourglass,
              label: context.tr('Awaiting approval'),
              value: '${dashboard.pendingApproval}',
            ),
            _Row(
              icon: WicchuIcons.newspaper,
              label: context.tr('Published today'),
              value: context.tr('{used} of {limit}', {
                'used': '${dashboard.publishedToday}',
                'limit': '${dashboard.dailyLimit}',
              }),
            ),
            _Row(
              icon: WicchuIcons.shieldCheck,
              label: context.tr('Publication'),
              value: context.tr(
                dashboard.approvalMode == 'automatic'
                    ? 'Automatic'
                    : 'Manual approval',
              ),
            ),
            const SizedBox(height: 12),
            _RecentActivity(dashboard: dashboard),
            if (waitingToday > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  context.tr(
                    '{count} waiting for approval already count toward today\'s limit.',
                    {'count': '$waitingToday'},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (dashboard.publishedToday == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Text(
                  context.tr(
                    'No news has been published today. Wicchu only publishes relevant articles from your sources, so a review does not always produce a post.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Text(
                context.tr(
                  'Times in your timezone ({zone}). The daily limit resets at {time} (00:00 {quotaZone}).',
                  {
                    'zone': DateTime.now().timeZoneName,
                    'time': _time(context, dashboard.quotaResetsAt),
                    'quotaZone': dashboard.timezone,
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (dashboard.pendingApproval > 0) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: onReviewPending,
                icon: const Icon(WicchuIcons.listChecks),
                label: Text(
                  context.tr('Review pending news ({count})', {
                    'count': '${dashboard.pendingApproval}',
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _time(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()));

  static String _dateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    return '${MaterialLocalizations.of(context).formatShortMonthDay(local)}, ${_time(context, value)}';
  }

  static String _statusTitle(String status) => switch (status) {
    'collecting' => 'Collecting news',
    'awaiting_approval' => 'Awaiting approval',
    'daily_limit_reached' => 'Daily limit reached',
    'configuration_needed' => 'Configuration needed',
    'paused' => 'Paused',
    'error' => 'Something needs attention',
    _ => 'Scheduled',
  };

  static String _statusDetail(LocalNewsDashboard dashboard) =>
      switch ((dashboard.status, dashboard.reason)) {
        ('collecting', _) => 'Wicchu is checking your sources now.',
        ('awaiting_approval', _) =>
          'News is waiting for your approval before it is published.',
        ('daily_limit_reached', _) =>
          'Today\'s news is used. Wicchu looks again after the daily reset.',
        ('configuration_needed', 'missing_categories') =>
          'Select at least one active news category.',
        ('configuration_needed', _) => 'Select at least one approved source.',
        ('paused', 'disabled') => 'Automated news is turned off.',
        ('paused', 'monthly_limit_reached') =>
          'The monthly limit has been reached.',
        ('paused', _) =>
          'News processing is paused by Wicchu. It will resume automatically.',
        ('error', 'sources_unavailable') =>
          'The selected news sources could not be read.',
        ('error', 'configuration_invalid') =>
          'The last review could not use your sources or categories.',
        ('error', _) => 'The last review failed. Wicchu will try again.',
        _ => 'Wicchu will check your sources at the next review.',
      };

  static String _runLabel(LocalNewsLastRun run) => switch (run.status) {
    'success' => 'Completed',
    'partial' => 'Completed with problems',
    'daily_limit_reached' => "Today's limit was already reached",
    _ => 'Failed',
  };
}

/// Shows what the system did last and what it will do next, from live dashboard data only.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.dashboard});

  final LocalNewsDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final run = dashboard.lastRun;
    final entries = <(IconData, String)>[];
    if (run == null) {
      entries.add((WicchuIcons.clockCounterClockwise, 'No activity yet'));
    } else {
      final found = run.published + run.pendingApproval;
      switch (run.status) {
        case 'success':
          entries.add((WicchuIcons.checkCircle, 'Review completed'));
          entries.add(
            found > 0
                ? (WicchuIcons.newspaper, 'Relevant news found')
                : (WicchuIcons.newspaper, 'No relevant news found'),
          );
        case 'partial':
          entries.add((
            WicchuIcons.warningCircle,
            'Review completed with problems',
          ));
        case 'daily_limit_reached':
          entries.add((
            WicchuIcons.clock,
            'Review skipped: daily limit already reached',
          ));
        default:
          entries.add((WicchuIcons.warningCircle, 'Review failed'));
      }
    }
    entries.add(
      dashboard.nextCollectionAt != null
          ? (WicchuIcons.calendarBlank, 'Next review scheduled')
          : (WicchuIcons.calendarBlank, 'Pending scheduling'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Recent activity'),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final (icon, text) in entries)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(text),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
