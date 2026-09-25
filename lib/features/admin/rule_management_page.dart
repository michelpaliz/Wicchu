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
  bool _orderMode = false;
  bool _showTip = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _rules = widget.repository.listRules(widget.community.id).then((data) {
      final sorted = [...data.rules]
        ..sort((a, b) => a.position.compareTo(b.position));
      return CommunityRules(
        rules: sorted,
        rulesVersion: data.rulesVersion,
        acceptedRulesVersion: data.acceptedRulesVersion,
        acceptanceRequired: data.acceptanceRequired,
        canManage: data.canManage,
      );
    });
  }

  Future<void> _openEditor([CommunityRule? rule]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityRuleEditorPage(
          rule: rule,
          communityName: widget.community.name,
          onSave: (title, description) async {
            if (rule == null) {
              final current = await _rules;
              await widget.repository.createRule(
                widget.community.id,
                title: title,
                description: description,
                position: current.rules.length,
              );
            } else {
              await widget.repository.updateRule(
                widget.community.id,
                rule,
                title: title,
                description: description,
              );
            }
          },
        ),
      ),
    );
    if (saved == true && mounted) setState(_reload);
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
    body: FutureBuilder<CommunityRules>(
      future: _rules,
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
                  Text(context.trError(snapshot.error!)),
                  TextButton(
                    onPressed: () => setState(_reload),
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final rules = snapshot.data!.rules;
        final canManage = snapshot.data!.canManage;
        final colors = Theme.of(context).colorScheme;
        return ReorderableListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          buildDefaultDragHandles: false,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _notice(
                icon: Icons.verified_user_outlined,
                title: 'A better space for everyone',
                description:
                    'These rules help keep your community safe, respectful and active.',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Rules ({count})', {
                        'count': '${rules.length}',
                      }),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canManage && rules.length > 1)
                    TextButton.icon(
                      onPressed: _reordering
                          ? null
                          : () => setState(() => _orderMode = !_orderMode),
                      icon: Icon(
                        _orderMode ? Icons.check : Icons.swap_vert,
                        size: 20,
                      ),
                      label: Text(context.tr(_orderMode ? 'Done' : 'Reorder')),
                    ),
                ],
              ),
              if (_reordering) const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
          ),
          footer: Column(
            children: [
              if (canManage) ...[
                const SizedBox(height: 28),
                if (rules.length < 2) ...[
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.article_outlined,
                          size: 54,
                          color: colors.primary,
                        ),
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: colors.primary,
                        child: Icon(
                          Icons.verified_user_outlined,
                          color: colors.onPrimary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('Keep your community safe'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Add clear rules so everyone knows how to participate.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _reordering ? null : () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Add rule')),
                ),
                if (_showTip) ...[
                  const SizedBox(height: 24),
                  _notice(
                    icon: Icons.lightbulb_outline,
                    title: 'Tip',
                    description:
                        'Use clear, specific rules. Tap Reorder to drag rules into place.',
                    onClose: () => setState(() => _showTip = false),
                  ),
                ],
              ] else if (rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.tr('No community rules yet.')),
                ),
            ],
          ),
          itemCount: rules.length,
          onReorderItem: (oldIndex, newIndex) {
            if (canManage && _orderMode && !_reordering) {
              _reorder(rules, oldIndex, newIndex);
            }
          },
          itemBuilder: (context, index) {
            final rule = rules[index];
            return Card(
              key: ValueKey(rule.id),
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colors.onSurface.withValues(alpha: .08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: colors.primary.withValues(alpha: .12),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rule.description,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.tr('Active rule'),
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canManage && _orderMode)
                      ReorderableDragStartListener(
                        index: index,
                        enabled: !_reordering,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.drag_handle, color: colors.primary),
                        ),
                      ),
                    if (canManage && !_orderMode)
                      PopupMenuButton<String>(
                        enabled: !_reordering,
                        tooltip: context.tr('Rule options'),
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
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
  Widget _notice({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onClose,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(description),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              tooltip: context.tr('Close'),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}

class CommunityRuleEditorPage extends StatefulWidget {
  const CommunityRuleEditorPage({
    super.key,
    this.rule,
    required this.communityName,
    required this.onSave,
  });
  final CommunityRule? rule;
  final String communityName;
  final Future<void> Function(String title, String description) onSave;
  @override
  State<CommunityRuleEditorPage> createState() =>
      CommunityRuleEditorPageState();
}

class CommunityRuleEditorPageState extends State<CommunityRuleEditorPage> {
  final _form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.rule?.title);
  late final description = TextEditingController(
    text: widget.rule?.description,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(title.text.trim(), description.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.trError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr(widget.rule == null ? 'Add rule' : 'Edit rule')),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                widget.communityName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Add clear rules so members know what is expected in this community.',
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: title,
                enabled: !_saving,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Rule title'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr('Enter a rule title.')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                enabled: !_saving,
                minLines: 6,
                maxLines: 12,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Description'),
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr('Describe this rule.')
                    : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(context.tr(_saving ? 'Saving…' : 'Save')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
