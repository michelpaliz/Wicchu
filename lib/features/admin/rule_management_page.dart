import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class RuleManagementPage extends StatefulWidget {
  const RuleManagementPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<RuleManagementPage> createState() => _RuleManagementPageState();
}

class _RuleManagementPageState extends State<RuleManagementPage> {
  late Future<CommunityRules> _rules;
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _rules = widget.repository.listRules(widget.community.id);
  }

  Future<void> _openEditor([CommunityRule? rule]) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _RuleEditorDialog(rule: rule),
    );
    if (result == null || !mounted) return;
    try {
      final current = await _rules;
      if (rule == null) {
        await widget.repository.createRule(
          widget.community.id,
          title: result.$1,
          description: result.$2,
          position: current.rules.length,
        );
      } else {
        await widget.repository.updateRule(
          widget.community.id,
          rule,
          title: result.$1,
          description: result.$2,
        );
      }
      if (mounted) setState(_reload);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(CommunityRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Delete rule?')),
        content: Text(
          dialogContext.tr(
            'Members will no longer see this rule. They will need to accept the updated rules.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteRule(widget.community.id, rule.id);
      if (mounted) setState(_reload);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reorder(
    List<CommunityRule> rules,
    int oldIndex,
    int newIndex,
  ) async {
    if (_reordering) return;
    final reordered = [...rules];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _reordering = true;
      _rules = Future.value(
        CommunityRules(
          rules: reordered,
          rulesVersion: 0,
          acceptedRulesVersion: 0,
          acceptanceRequired: false,
          canManage: true,
        ),
      );
    });
    try {
      for (final (index, rule) in reordered.indexed) {
        if (rule.position != index) {
          await widget.repository.updateRule(
            widget.community.id,
            rule,
            position: index,
          );
        }
      }
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) setState(_reload);
      _showError(error);
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  void _preview(List<CommunityRule> rules) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              sheetContext.tr('Community rules'),
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final (index, rule) in rules.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(rule.title),
                subtitle: Text(rule.description),
              ),
          ],
        ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.trError(error))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Community rules')),
      actions: [
        FutureBuilder<CommunityRules>(
          future: _rules,
          builder: (context, snapshot) => IconButton(
            tooltip: context.tr('Preview'),
            onPressed: snapshot.hasData
                ? () => _preview(snapshot.data!.rules)
                : null,
            icon: const Icon(Icons.visibility_outlined),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _reordering ? null : () => _openEditor(),
      icon: const Icon(Icons.add),
      label: Text(context.tr('Add rule')),
    ),
    body: FutureBuilder<CommunityRules>(
      future: _rules,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final rules = snapshot.data!.rules;
        if (rules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.tr(
                  'Add clear rules so members know what is expected in this community.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: rules.length,
          onReorderItem: (oldIndex, newIndex) =>
              _reorder(rules, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final rule = rules[index];
            return Card(
              key: ValueKey(rule.id),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(rule.title),
                subtitle: Text(
                  rule.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _openEditor(rule);
                    if (action == 'delete') _delete(rule);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.tr('Edit rule')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.tr('Delete rule')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({this.rule});
  final CommunityRule? rule;
  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  late final title = TextEditingController(text: widget.rule?.title);
  late final description = TextEditingController(
    text: widget.rule?.description,
  );
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr(widget.rule == null ? 'Add rule' : 'Edit rule')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.tr('Rule title')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.tr('Description')),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Cancel')),
      ),
      FilledButton(
        onPressed: () {
          final normalizedTitle = title.text.trim();
          final normalizedDescription = description.text.trim();
          if (normalizedTitle.isEmpty || normalizedDescription.isEmpty) {
            return;
          }
          Navigator.pop(context, (normalizedTitle, normalizedDescription));
        },
        child: Text(context.tr('Save')),
      ),
    ],
  );
}
