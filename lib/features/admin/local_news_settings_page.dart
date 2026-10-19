import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';

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

  void _apply(LocalNewsSettings settings) {
    _settings = settings;
    _enabled = settings.enabled;
    _sourceIds = settings.sourceIds.toSet();
    _categoryIds = settings.categoryIds.toSet();
    _language = settings.language;
    _approvalMode = settings.approvalMode;
  }

  Future<void> _save() async {
    if (_enabled && (_sourceIds.isEmpty || _categoryIds.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Select at least one news source and category.'),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final settings = await widget.repository.updateLocalNewsSettings(
        widget.community.id,
        enabled: _enabled,
        sourceIds: _sourceIds.toList(),
        categoryIds: _categoryIds.toList(),
        language: _language,
        approvalMode: _approvalMode,
      );
      if (!mounted) return;
      setState(() {
        _apply(settings);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Local News settings saved.'))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _runNow() async {
    setState(() => _running = true);
    try {
      final result = await widget.repository.runLocalNewsNow(
        widget.community.id,
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _data = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Processed {count} news articles.', {
              'count': '${result.processed}',
            }),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _running = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
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
          return Center(
            child: FilledButton(
              onPressed: () => setState(() => _data = _load()),
              child: Text(context.tr('Retry')),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final entitled = data.settings.entitled;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(WicchuIcons.newspaper, size: 30),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('News matched to your community'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Wicchu checks approved sources and uses your community subject and categories to find relevant articles.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      label: Text(
                        context.tr('{tier} · {count} posts per month', {
                          'tier': data.settings.subscriptionTier.toUpperCase(),
                          'count': '${data.settings.monthlyLimit}',
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Limit: one automated news post per community each day, and never more than one in the same category.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _title('Available plans'),
            _planCard(
              data.settings,
              tier: 'free',
              description: 'Automated news is not included.',
            ),
            _planCard(
              data.settings,
              tier: 'pro',
              description:
                  'Approved sources, category matching, and review before publishing.',
            ),
            _planCard(
              data.settings,
              tier: 'business',
              description:
                  'Higher monthly ceiling and automatic publishing from trusted sources.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                context.tr(
                  'Contact Wicchu to activate or change a plan. Self-service billing is not available yet.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            if (!entitled)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.tr(
                      'Local News access must be enabled for this community by Wicchu.',
                    ),
                  ),
                ),
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Enable automated news')),
                subtitle: Text(
                  context.tr(
                    'The scheduler will check for relevant articles automatically.',
                  ),
                ),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const Divider(),
              _title('News language'),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'es',
                    label: Text(context.tr('Spanish')),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(context.tr('English')),
                  ),
                ],
                selected: {_language},
                onSelectionChanged: (values) =>
                    setState(() => _language = values.first),
              ),
              const SizedBox(height: 22),
              _title('Publication approval'),
              RadioGroup<String>(
                groupValue: _approvalMode,
                onChanged: (value) =>
                    setState(() => _approvalMode = value ?? 'manual'),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'manual',
                      title: Text(context.tr('Review before publishing')),
                      subtitle: Text(
                        context.tr('Recommended for every new source.'),
                      ),
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
                Text(context.tr('No approved news sources are available.')),
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
      },
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

  Widget _planCard(
    LocalNewsSettings settings, {
    required String tier,
    required String description,
  }) {
    final current = settings.subscriptionTier == tier;
    final limit = settings.tierLimits[tier] ?? 0;
    final plan = settings.plans.where((item) => item.tier == tier).firstOrNull;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: current ? colors.primaryContainer : null,
      child: ListTile(
        leading: Icon(
          current ? WicchuIcons.checkCircle : WicchuIcons.newspaper,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tier.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (current) Chip(label: Text(context.tr('Current plan'))),
          ],
        ),
        subtitle: Text(
          '${_planPrice(plan)}\n${context.tr(description)}\n${limit == 0 ? context.tr('No automated posts') : context.tr('Up to {count} posts per month · daily limit applies', {'count': '$limit'})}',
        ),
        isThreeLine: true,
      ),
    );
  }

  String _planPrice(LocalNewsPlan? plan) {
    if (plan == null || (plan.priceEur == 0 && plan.priceUsd == 0)) {
      return context.tr('Free');
    }
    return context.tr('€{eur} / \${usd} per month', {
      'eur': plan.priceEur.toStringAsFixed(2),
      'usd': plan.priceUsd.toStringAsFixed(2),
    });
  }

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
