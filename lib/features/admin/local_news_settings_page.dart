import 'dart:convert';

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
  Object? sourcesError,
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
  _LocalNewsData? _data;
  Object? _error;
  bool _loading = true;
  LocalNewsSettings? _settings;
  Set<String> _sourceIds = {};
  Set<String> _categoryIds = {};
  String _language = 'es';
  String _approvalMode = 'manual';
  bool _enabled = false;
  bool _saving = false;
  bool _running = false;
  int _loadGeneration = 0;
  String? _activationError;

  bool _allowPop = false;
  bool _confirmingLeave = false;
  String _draftKey(
    bool enabled,
    Iterable<String> sources,
    Iterable<String> categories,
    String language,
    String approval,
  ) => jsonEncode([
    enabled,
    sources.toList()..sort(),
    categories.toList()..sort(),
    language,
    approval,
  ]);
  bool get _dirty {
    final saved = _settings;
    return saved != null &&
        _draftKey(
              _enabled,
              _sourceIds,
              _categoryIds,
              _language,
              _approvalMode,
            ) !=
            _draftKey(
              saved.enabled,
              saved.sourceIds,
              saved.categoryIds,
              saved.language,
              saved.approvalMode,
            );
  }

  Future<void> _leave() async {
    if (_saving || _running || _confirmingLeave) return;
    if (_dirty) {
      _confirmingLeave = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('Unsaved changes')),
          content: Text(context.tr('Save your changes before leaving?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Keep editing')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Discard')),
            ),
          ],
        ),
      );
      _confirmingLeave = false;
      if (!mounted || discard != true) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final values = await Future.wait<Object>([
        widget.repository.getLocalNewsSettings(widget.community.id),
        widget.repository
            .listLocalNewsSources()
            .then<Object>((sources) => (sources: sources, error: null))
            .catchError(
              (Object error) => (sources: <LocalNewsSource>[], error: error),
            ),
        widget.repository.listCategories(widget.community.id),
        widget.repository.listLocalNewsArticles(widget.community.id),
      ]);
      final data = (
        settings: values[0] as LocalNewsSettings,
        sources: (values[1] as ({List<LocalNewsSource> sources, Object? error}))
            .sources,
        sourcesError:
            (values[1] as ({List<LocalNewsSource> sources, Object? error}))
                .error,
        categories: values[2] as List<CommunityCategory>,
        articles: values[3] as List<LocalNewsArticle>,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
        // Adopt server state into the working draft only when there are no
        // unsaved edits, so a background refresh never discards the user's
        // in-progress selections.
        if (!_dirty) {
          _apply(data.settings);
          // Removed sources/categories must not remain invisible publishing targets.
          if (!data.settings.isPilot) {
            _sourceIds.retainAll(data.sources.map((source) => source.id));
          }
          _categoryIds.retainAll(
            data.categories.map((category) => category.id),
          );
        }
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _reload() => _load();

  void _apply(LocalNewsSettings settings) {
    _settings = settings;
    _enabled = settings.enabled;
    _sourceIds = settings.sourceIds.toSet();
    _categoryIds = settings.categoryIds.toSet();
    _language = settings.language;
    _approvalMode = settings.isPilot ? 'manual' : settings.approvalMode;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() => _persist(_enabled);

  Future<void> _persist(bool enabled) async {
    if (_saving || _running) return;
    setState(() => _saving = true);
    try {
      final data = _data;
      if (!mounted) return;
      if (data == null) {
        setState(() => _saving = false);
        return;
      }
      String? error;
      if (enabled) {
        if (!data.settings.isPilot && data.sourcesError != null) {
          error = context.tr(
            'Could not load news sources. Refresh and try again.',
          );
        } else if (!data.settings.isPilot && data.sources.isEmpty) {
          error = context.tr(
            'No news sources are configured yet. Refresh sources to check again.',
          );
        } else if (!data.settings.isPilot &&
            (_sourceIds.isEmpty ||
                !_sourceIds.every(
                  (id) => data.sources.any((source) => source.id == id),
                ))) {
          error = context.tr('Select an available approved news source.');
        } else if (_categoryIds.isEmpty ||
            !_categoryIds.every(
              (id) => data.categories.any((category) => category.id == id),
            )) {
          error = context.tr('Select an available news category.');
        }
      }
      if (error != null) {
        setState(() {
          _saving = false;
          _activationError = error;
        });
        return;
      }
      final saved = await widget.repository.updateLocalNewsSettings(
        widget.community.id,
        enabled: enabled,
        sourceIds: _sourceIds.toList(),
        categoryIds: _categoryIds.toList(),
        language: _language,
        approvalMode: _approvalMode,
      );
      if (!mounted) return;
      setState(() {
        _apply(saved);
        _saving = false;
        _activationError = null;
      });
      _showMessage(context.tr('Local News settings saved.'));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _activationError = context.trError(error);
        _enabled = enabled;
      });
    }
  }

  Future<void> _runNow() async {
    if (_saving || _running || _dirty || _settings?.enabled != true) return;
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
        await _load();
        if (mounted) setState(() => _running = false);
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
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_saving && !_running),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.community.name),
            Text(
              context.tr('Automated news'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: _saving || _running ? null : _reload,
            icon: const Icon(WicchuIcons.arrowsClockwise),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          (_error == null && _data != null && (_dirty || _saving))
          ? _saveBar()
          : null,
    ),
  );

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final error = _error;
      if (error is ApiException && error.statusCode == 403) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr('Automated news is not available for this community.'),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('Unable to load news settings. Please try again.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _reload,
                child: Text(context.tr('Retry')),
              ),
            ],
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();
    return AbsorbPointer(
      absorbing: _saving,
      child: RefreshIndicator(onRefresh: _reload, child: _settingsView(data)),
    );
  }

  Widget _saveBar() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: FilledButton.icon(
      onPressed: _saving || _running || !_dirty ? null : _save,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(WicchuIcons.floppyDisk),
      label: Text(context.tr('Save settings')),
    ),
  );

  Widget _settingsView(_LocalNewsData data) {
    final settings = data.settings;
    final entitled = settings.entitled;
    final selectedSourceCount = data.sources
        .where((source) => _sourceIds.contains(source.id))
        .length;
    final selectedCategoryCount = data.categories
        .where((category) => _categoryIds.contains(category.id))
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (settings.isPilot) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const Icon(WicchuIcons.checkCircle, size: 18),
              label: Text(context.tr('Pilot access active')),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _LocalNewsStatusSection(
          dashboard: settings.dashboard,
          enabled: _enabled,
          entitled: entitled,
          running: _running,
          hasUnsavedChanges: _dirty,
          hasSources: settings.isPilot
              ? settings.sourceIds.isNotEmpty
              : data.sources.isNotEmpty,
          sourcesError: data.sourcesError != null,
          isPilot: settings.isPilot,
          onEnabledChanged: _persist,
          onReviewPending: _reviewPending,
          onRunNow: _runNow,
        ),
        if (_activationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _activationError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        if (!entitled)
          _noticeCard(
            icon: WicchuIcons.shieldWarning,
            text: context.tr(
              'Local News access must be enabled for this community by Wicchu.',
            ),
          ),
        if (settings.isPilot)
          _noticeCard(
            icon: WicchuIcons.newspaper,
            text: context.tr(
              settings.sourceIds.isEmpty
                  ? 'News sources are unavailable for this community. Wicchu assigns verified sources automatically.'
                  : 'Wicchu assigns verified news sources based on your community. No RSS link is needed.',
            ),
          ),
        _title('Configuration'),
        const SizedBox(height: 4),
        Text(
          context.tr('News language'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'es', label: Text(context.tr('Spanish'))),
              ButtonSegment(value: 'en', label: Text(context.tr('English'))),
            ],
            selected: {_language},
            onSelectionChanged: _saving
                ? null
                : (values) => setState(() => _language = values.first),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _approvalMode,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Approval mode')),
          items: [
            DropdownMenuItem(
              value: 'manual',
              child: Text(context.tr('Review before publishing')),
            ),
            if (!settings.isPilot)
              DropdownMenuItem(
                value: 'automatic',
                child: Text(context.tr('Publish automatically')),
              ),
          ],
          onChanged: _saving || settings.isPilot
              ? null
              : (value) {
                  if (value != null) setState(() => _approvalMode = value);
                },
        ),
        if (_approvalMode == 'automatic') ...[
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Only sources trusted and authorized by Wicchu can publish automatically.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (!settings.isPilot) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          _settingsExpansion(
            icon: WicchuIcons.newspaper,
            title: 'Approved sources',
            summary: data.sourcesError != null
                ? context.tr(
                    'Could not load news sources. Refresh and try again.',
                  )
                : data.sources.isEmpty
                ? context.tr(
                    'No news sources are configured yet. Refresh sources to check again.',
                  )
                : context.tr('{selected} of {total} selected', {
                    'selected': '$selectedSourceCount',
                    'total': '${data.sources.length}',
                  }),
            children: [
              if (data.sourcesError != null) ...[
                Text(
                  context.tr(
                    'Could not load news sources. Refresh and try again.',
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(WicchuIcons.arrowsClockwise),
                    label: Text(context.tr('Refresh approved sources')),
                  ),
                ),
              ] else if (data.sources.isEmpty) ...[
                Text(
                  context.tr(
                    'No news sources are configured yet. Refresh sources to check again.',
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(WicchuIcons.arrowsClockwise),
                    label: Text(context.tr('Refresh approved sources')),
                  ),
                ),
              ] else
                for (final source in data.sources)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _sourceIds.contains(source.id),
                    title: Text(source.name),
                    subtitle: Text(
                      context.tr(
                        source.trusted && source.authorizedForAutoPublish
                            ? 'Trusted for automatic publishing'
                            : 'Review required',
                      ),
                    ),
                    onChanged: (bool? checked) => setState(() {
                      checked == true
                          ? _sourceIds.add(source.id)
                          : _sourceIds.remove(source.id);
                    }),
                  ),
            ],
          ),
        ],
        const Divider(height: 1),
        _settingsExpansion(
          icon: WicchuIcons.tag,
          title: 'News categories',
          summary: data.categories.isEmpty
              ? context.tr('No news categories are available.')
              : context.tr('{selected} of {total} selected', {
                  'selected': '$selectedCategoryCount',
                  'total': '${data.categories.length}',
                }),
          children: [
            if (data.categories.isEmpty)
              Text(context.tr('No news categories are available.'))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in data.categories)
                    FilterChip(
                      label: Text(category.name),
                      selected: _categoryIds.contains(category.id),
                      onSelected: (selected) => setState(() {
                        selected
                            ? _categoryIds.add(category.id)
                            : _categoryIds.remove(category.id);
                      }),
                    ),
                ],
              ),
          ],
        ),
        if (data.articles.isNotEmpty) ...[
          const Divider(height: 1),
          _settingsExpansion(
            icon: WicchuIcons.clockCounterClockwise,
            title: 'Recent news activity',
            summary: context.tr('{count} recent items', {
              'count': '${data.articles.take(10).length}',
            }),
            children: [
              for (final article in data.articles.take(10))
                ListTile(
                  dense: true,
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
          ),
        ],
      ],
    );
  }

  Widget _settingsExpansion({
    required IconData icon,
    required String title,
    required String summary,
    required List<Widget> children,
  }) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    shape: const Border(),
    collapsedShape: const Border(),
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(context.tr(title)),
    subtitle: Text(summary),
    children: children,
  );

  Widget _noticeCard({required IconData icon, required String text}) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
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
class _LocalNewsStatusSection extends StatelessWidget {
  const _LocalNewsStatusSection({
    required this.dashboard,
    required this.enabled,
    required this.entitled,
    required this.running,
    required this.hasUnsavedChanges,
    required this.hasSources,
    required this.sourcesError,
    required this.isPilot,
    required this.onEnabledChanged,
    required this.onReviewPending,
    required this.onRunNow,
  });

  final LocalNewsDashboard? dashboard;
  final bool enabled;
  final bool entitled;
  final bool running;
  final bool hasUnsavedChanges;
  final bool hasSources;
  final bool sourcesError;
  final bool isPilot;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onReviewPending;
  final VoidCallback onRunNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final value = dashboard;
    final run = value?.lastRun;
    final status = value?.status;
    final (IconData icon, Color tone) = switch (status) {
      'collecting' => (WicchuIcons.arrowsClockwise, colors.primary),
      'awaiting_approval' => (WicchuIcons.hourglass, colors.tertiary),
      'daily_limit_reached' => (WicchuIcons.clock, colors.secondary),
      'configuration_needed' => (WicchuIcons.gearSix, colors.error),
      'paused' => (WicchuIcons.pause, colors.outline),
      'error' => (WicchuIcons.warningCircle, colors.error),
      null => (WicchuIcons.warningCircle, colors.outline),
      _ => (WicchuIcons.calendarBlank, colors.primary),
    };
    final waitingToday = value == null
        ? 0
        : value.todayUsed - value.publishedToday;
    final statusTitle = value == null
        ? 'Scheduler unavailable'
        : isPilot &&
              value.status == 'configuration_needed' &&
              value.reason == 'missing_sources'
        ? 'Waiting for news sources'
        : _statusTitle(value.status);
    final statusDetail = value == null
        ? 'Scheduling information is temporarily unavailable. Refresh to try again.'
        : _statusDetail(value, isPilot: isPilot);
    final compactMetrics =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    final metrics = <_MetricData>[
      (
        icon: WicchuIcons.calendarBlank,
        label: context.tr('Next review'),
        value: value?.nextCollectionAt == null
            ? context.tr('Next review not available')
            : _dateTime(context, value!.nextCollectionAt!),
      ),
      (
        icon: WicchuIcons.hourglass,
        label: context.tr('Pending approvals'),
        value: '${value?.pendingApproval ?? 0}',
      ),
      (
        icon: WicchuIcons.newspaper,
        label: context.tr('Published today'),
        value: value == null
            ? '—'
            : context.tr('{used} of {limit}', {
                'used': '${value.publishedToday}',
                'limit': '${value.dailyLimit}',
              }),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: tone, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(statusTitle),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Enable automated news')),
          subtitle: Text(
            context.tr(statusDetail),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          value: enabled,
          onChanged: entitled ? onEnabledChanged : null,
        ),
        if (!isPilot && (sourcesError || !hasSources))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.tr(
                sourcesError
                    ? 'Could not load news sources. Refresh and try again.'
                    : 'No news sources are configured yet. Refresh sources to check again.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 4),
        if (compactMetrics)
          for (final metric in metrics)
            _MetricRow(
              icon: metric.icon,
              label: metric.label,
              value: metric.value,
            )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  if (index > 0) const VerticalDivider(width: 16),
                  Expanded(
                    child: _Metric(
                      icon: metrics[index].icon,
                      label: metrics[index].label,
                      value: metrics[index].value,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(WicchuIcons.clockCounterClockwise, size: 20),
          title: Text(context.tr('Last review')),
          subtitle: Text(
            run == null
                ? context.tr('Not run yet')
                : '${context.tr(_runLabel(run))} · ${_dateTime(context, run.finishedAt)}',
          ),
        ),
        if (waitingToday > 0)
          Text(
            context.tr(
              '{count} waiting for approval already count toward today\'s limit.',
              {'count': '$waitingToday'},
            ),
            style: theme.textTheme.bodySmall,
          ),
        if (value != null)
          Text(
            context.tr(
              'Times in your timezone ({zone}). The daily limit resets at {time} (00:00 {quotaZone}).',
              {
                'zone': DateTime.now().timeZoneName,
                'time': _time(context, value.quotaResetsAt),
                'quotaZone': value.timezone,
              },
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        if (value?.pendingApproval case final count? when count > 0) ...[
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: onReviewPending,
            icon: const Icon(WicchuIcons.listChecks),
            label: Text(
              context.tr('Review pending news ({count})', {'count': '$count'}),
            ),
          ),
        ],
        if (enabled) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: running || hasUnsavedChanges ? null : onRunNow,
            icon: running
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(WicchuIcons.arrowsClockwise),
            label: Text(context.tr('Check for news now')),
          ),
        ],
      ],
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

  static String _statusDetail(
    LocalNewsDashboard dashboard, {
    required bool isPilot,
  }) => switch ((dashboard.status, dashboard.reason)) {
    ('collecting', _) => 'Wicchu is checking your sources now.',
    ('awaiting_approval', _) =>
      'News is waiting for your approval before it is published.',
    ('daily_limit_reached', _) =>
      'Today\'s news is used. Wicchu looks again after the daily reset.',
    ('configuration_needed', 'missing_categories') =>
      'Select at least one active news category.',
    ('configuration_needed', _) =>
      isPilot
          ? 'Wicchu is preparing verified news sources. Collection will start when a source is available.'
          : 'Select at least one approved source.',
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

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _MetricData = ({IconData icon, String label, String value});
