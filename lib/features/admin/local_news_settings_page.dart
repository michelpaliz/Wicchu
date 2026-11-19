import 'package:flutter/material.dart';

import '../../data/authenticated_api_client.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'pending_posts_page.dart';

/// Owner/co-admin surface. RSS and AI internals stay out of this screen.
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
  LocalNewsSettings? _settings;
  List<CommunityCategory> _categories = const [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  String? _categoryId;
  String _language = 'es';
  String _approvalMode = 'manual';
  String? _categoryError;
  String? _includeError;
  final _include = TextEditingController();
  final _exclude = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _include.dispose();
    _exclude.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        widget.repository.getLocalNewsSettings(widget.community.id),
        widget.repository.listCategories(widget.community.id),
      ]);
      if (!mounted) return;
      final settings = values[0] as LocalNewsSettings;
      final rule = settings.newsRules.where((item) => item.enabled).firstOrNull;
      setState(() {
        _settings = settings;
        _categories = values[1] as List<CommunityCategory>;
        _categoryId = rule?.categoryId;
        _include.text = rule?.include ?? '';
        _exclude.text = rule?.exclude ?? '';
        _language = rule?.language ?? settings.language;
        _approvalMode = settings.isPilot
            ? 'manual'
            : (rule?.approvalMode ?? settings.approvalMode);
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  LocalNewsRule? get _draftRule {
    final categoryId = _categoryId;
    final include = _include.text.trim();
    if (categoryId == null || include.isEmpty) return null;
    return LocalNewsRule(
      categoryId: categoryId,
      include: include,
      exclude: _exclude.text.trim(),
      language: _language,
      approvalMode: _approvalMode,
    );
  }

  Future<void> _activateOrSave() async {
    final categoryError = _categoryId == null
        ? 'Select a category for these news posts.'
        : null;
    final include = _include.text.trim();
    final includeError = include.isEmpty
        ? 'Describe the news Wicchu should find.'
        : include.length < 20
        ? 'Add at least 20 characters so Wicchu can find relevant news.'
        : null;
    setState(() {
      _categoryError = categoryError;
      _includeError = includeError;
    });
    if (categoryError != null || includeError != null) return;
    await _save(enabled: true);
  }

  Future<void> _save({required bool enabled}) async {
    if (_saving) return;
    final rule = _draftRule;
    if (rule == null) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateLocalNewsSettings(
        widget.community.id,
        enabled: enabled,
        sourceIds: const [],
        categoryIds: [rule.categoryId],
        language: rule.language,
        approvalMode: rule.approvalMode,
        newsRules: [rule],
      );
      if (!mounted) return;
      _message(enabled ? 'Automatic News activated.' : 'Settings saved.');
      await _load();
    } catch (error) {
      if (mounted) _message(context.trError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (enabled) {
        await widget.repository.resumeLocalNews(widget.community.id);
      } else {
        await widget.repository.pauseLocalNews(widget.community.id);
      }
      if (mounted) await _load();
    } catch (error) {
      if (mounted) _message(context.trError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reviewPending() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PendingPostsPage(
          community: widget.community,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.tr(message))));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.community.name),
          Text(
            context.tr('Automated news'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _saving ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: context.tr('Refresh'),
        ),
      ],
    ),
    body: _body(),
  );

  Widget _body() {
    if (_loading && _settings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final unavailable =
          _error is ApiException && (_error as ApiException).statusCode == 403;
      return _EmptyState(
        icon: unavailable ? Icons.lock_outline : Icons.error_outline,
        title: unavailable
            ? 'Automated news is not available'
            : 'Unable to load Automatic News',
        detail: unavailable
            ? 'This feature is not available for this community.'
            : 'Please try again.',
        action: _load,
        actionLabel: 'Retry',
      );
    }
    final settings = _settings!;
    if (settings.newsRules.isEmpty) return _setup(settings);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                Tab(text: context.tr('Summary')),
                Tab(text: context.tr('Pending')),
                Tab(text: context.tr('Settings')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _overview(settings),
                _pending(settings),
                _settingsForm(settings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setup(LocalNewsSettings settings) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Text(
                context.tr('Activate automated news'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'Wicchu will look for relevant content automatically.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _formFields(settings),
            ],
          ),
        ),
        if (!keyboardOpen)
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _activateOrSave,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Continue')),
              ),
            ),
          ),
      ],
    );
  }

  Widget _overview(LocalNewsSettings settings) {
    final dashboard = settings.dashboard;
    final preparation = settings.sourcePreparationStatus;
    final state = dashboard?.serviceState ?? _serviceState(settings);
    final message = _statusMessage(state, preparation, dashboard?.status);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Automatic news')),
            subtitle: Text(
              context.tr(
                settings.activationRequested
                    ? 'Service active'
                    : 'Service paused',
              ),
            ),
            value: settings.activationRequested,
            onChanged: _saving ? null : _toggle,
          ),
          const SizedBox(height: 12),
          _StatusPanel(title: message.$1, detail: message.$2, icon: message.$3),
          const SizedBox(height: 16),
          _MetricGrid(
            items: [
              (
                'Next news check',
                _formatDate(dashboard?.nextCollectionAt),
                Icons.schedule_outlined,
              ),
              (
                'Verified sources',
                _sourcesLabel(state, preparation),
                Icons.rss_feed_outlined,
              ),
              (
                'Published today',
                '${dashboard?.publishedToday ?? 0}/${dashboard?.dailyLimit ?? 1}',
                Icons.newspaper_outlined,
              ),
              (
                'Pending',
                '${dashboard?.pendingApproval ?? 0}',
                Icons.pending_actions_outlined,
              ),
            ],
          ),
          if (dashboard?.upcomingArticle case final article?) ...[
            const SizedBox(height: 16),
            _UpcomingArticle(article: article, onReview: _reviewPending),
          ],
          if (state == 'no_sources') ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _message(
                'Invite contributors to share reliable local news while Wicchu continues searching.',
              ),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(context.tr('Invite contributor')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pending(LocalNewsSettings settings) {
    final count = settings.dashboard?.pendingApproval ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (count == 0)
          const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending news',
            detail: 'When Wicchu prepares an article, it will appear here.',
          )
        else ...[
          Text(
            context.tr('{count} news item waiting for review', {
              'count': '$count',
            }),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Moderators can also approve these articles from the moderation area.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _reviewPending,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(context.tr('Review pending news')),
          ),
        ],
      ],
    );
  }

  Widget _settingsForm(LocalNewsSettings settings) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _formFields(settings),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _saving
            ? null
            : () => _save(enabled: settings.activationRequested),
        child: Text(context.tr('Save settings')),
      ),
    ],
  );

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      context.tr(label),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
    ),
  );

  Widget _formFields(LocalNewsSettings settings) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel('Post category *'),
      DropdownButtonFormField<String>(
        key: ValueKey(_categoryId),
        isExpanded: true,
        initialValue: _categories.any((category) => category.id == _categoryId)
            ? _categoryId
            : null,
        decoration: InputDecoration(
          hintText: context.tr('Select a category'),
          errorText: _categoryError == null
              ? null
              : context.tr(_categoryError!),
        ),
        items: _categories
            .map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Text(context.trForAppLanguage(category.name)),
              ),
            )
            .toList(growable: false),
        onChanged: _saving
            ? null
            : (value) => setState(() {
                _categoryId = value;
                _categoryError = null;
              }),
      ),
      const SizedBox(height: 14),
      _fieldLabel('News topics *'),
      TextField(
        controller: _include,
        maxLength: 500,
        minLines: 3,
        maxLines: 5,
        onChanged: (_) => setState(() => _includeError = null),
        decoration: InputDecoration(
          hintText: context.tr('What should Wicchu look for?'),
          helperText: context.tr(
            'Be specific about topics that interest your community.',
          ),
          errorText: _includeError == null ? null : context.tr(_includeError!),
        ),
      ),
      const SizedBox(height: 10),
      _fieldLabel('Excluded content'),
      TextField(
        controller: _exclude,
        maxLength: 300,
        minLines: 1,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: context.tr('Optional: what should Wicchu avoid?'),
        ),
      ),
      const SizedBox(height: 14),
      _fieldLabel('Language *'),
      SegmentedButton<String>(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        segments: const [
          ButtonSegment(value: 'es', label: Text('Español')),
          ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {_language},
        onSelectionChanged: _saving
            ? null
            : (value) => setState(() => _language = value.first),
      ),
      const SizedBox(height: 14),
      if (settings.isPilot) ...[
        _fieldLabel('Publication approval'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Review before publishing')),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                        'Pilot news always waits for your approval before publication.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ] else ...[
        _fieldLabel('Publication mode *'),
        DropdownButtonFormField<String>(
          key: ValueKey(_approvalMode),
          isExpanded: true,
          initialValue: _approvalMode,
          decoration: InputDecoration(
            hintText: context.tr('Select a publication mode'),
          ),
          items: [
            DropdownMenuItem(
              value: 'manual',
              child: Text(context.tr('Review before publishing')),
            ),
            DropdownMenuItem(
              value: 'automatic',
              child: Text(context.tr('Publish automatically')),
            ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _approvalMode = value ?? 'manual'),
        ),
      ],
    ],
  );

  String _serviceState(LocalNewsSettings settings) =>
      !settings.activationRequested
      ? (settings.newsRules.isEmpty ? 'not_configured' : 'paused')
      : (settings.enabled ? 'active' : 'discovering_sources');
  (String, String, IconData) _statusMessage(
    String state,
    String preparation,
    String? dashboardStatus,
  ) {
    if (state == 'no_sources' || preparation == 'no_sources') {
      return (
        'No verified sources yet',
        'We have not found verified sources for this community. Your configuration is saved.',
        Icons.rss_feed_outlined,
      );
    }
    if (state == 'awaiting_source_approval' ||
        preparation == 'awaiting_approval') {
      return (
        'Waiting for source approval',
        'Wicchu is verifying sources. This may take time.',
        Icons.verified_outlined,
      );
    }
    if (state == 'discovering_sources' ||
        preparation == 'queued' ||
        preparation == 'searching') {
      return (
        'Preparing your news',
        'Wicchu is searching for and verifying relevant sources. You can leave this screen.',
        Icons.travel_explore_outlined,
      );
    }
    if (state == 'paused') {
      return (
        'Automatic News is paused',
        'Your preferences and pending articles are saved.',
        Icons.pause_circle_outline,
      );
    }
    if (dashboardStatus == 'collecting') {
      return (
        'Checking the latest news',
        'Wicchu is reviewing approved sources now.',
        Icons.sync_outlined,
      );
    }
    if (dashboardStatus == 'no_news_found') {
      return (
        'Everything is working',
        'We will keep looking for relevant news for your community.',
        Icons.check_circle_outline,
      );
    }
    if (dashboardStatus == 'awaiting_approval') {
      return (
        'News ready for review',
        'You have a prepared article waiting for approval.',
        Icons.fact_check_outlined,
      );
    }
    if (dashboardStatus == 'daily_limit_reached') {
      return (
        'Today’s post is published',
        'We will keep looking for new articles.',
        Icons.today_outlined,
      );
    }
    if (dashboardStatus == 'source_error') {
      return (
        'Some sources are unavailable',
        'Wicchu will try them again automatically.',
        Icons.warning_amber_outlined,
      );
    }
    if (state == 'error' || dashboardStatus == 'error') {
      return (
        'Automatic News needs attention',
        'We could not complete the latest check. Wicchu will try again automatically.',
        Icons.error_outline,
      );
    }
    return (
      'Ready to look for news',
      'Wicchu will check verified sources automatically every six hours.',
      Icons.check_circle_outline,
    );
  }

  String _sourcesLabel(String state, String preparation) =>
      state == 'no_sources' || preparation == 'no_sources'
      ? 'No sources found'
      : state == 'awaiting_source_approval' ||
            preparation == 'awaiting_approval'
      ? 'Waiting for approval'
      : state == 'discovering_sources' ||
            preparation == 'queued' ||
            preparation == 'searching'
      ? 'Preparing'
      : 'Ready';
  String _formatDate(DateTime? value) {
    if (value == null) return context.tr('To be scheduled');
    final local = value.toLocal();
    return '${MaterialLocalizations.of(context).formatShortMonthDay(local)}, ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.detail,
    required this.icon,
  });
  final String title;
  final String detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(title),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(context.tr(detail)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<(String, String, IconData)> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 8.0;
      final itemWidth = (constraints.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: items
            .map(
              (item) => SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, size: 18),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(item.$2),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(item.$1),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      );
    },
  );
}

class _UpcomingArticle extends StatelessWidget {
  const _UpcomingArticle({required this.article, required this.onReview});
  final LocalNewsUpcomingArticle article;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Next publication'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(article.title, style: Theme.of(context).textTheme.titleMedium),
          if (article.sourceName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${context.tr('Source')}: ${article.sourceName}'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onReview,
            child: Text(context.tr('Review article')),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
    this.actionLabel,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? action;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(context.tr(detail), textAlign: TextAlign.center),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton(
                onPressed: action,
                child: Text(context.tr(actionLabel ?? 'Continue')),
              ),
            ),
        ],
      ),
    ),
  );
}
