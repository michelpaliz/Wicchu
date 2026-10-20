import '../../widgets/wicchu_list_tile.dart';
import '../../widgets/category_symbol.dart';
import 'dart:convert';
import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_input_limits.dart';
import 'package:flutter/services.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../services/post_image_preparation.dart';
import 'rule_management_page.dart';
import 'official_links_page.dart';
import 'business_services_page.dart';
import 'page_appearance_editor.dart';
import 'restaurant_settings_page.dart';
import 'page_location_settings_page.dart';
import '../community/community_invitations_page.dart';
import '../community/user_avatar.dart';
import '../profile/member_profile_page.dart';
import '../../widgets/profile_accent_picker.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  late Future<List<CommunityCategory>> _categories = widget.repository
      .listCategories(widget.community.id);
  bool _reordering = false;

  void _reload() => setState(() {
    _categories = widget.repository.listCategories(widget.community.id);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Categories'))),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Align(
          heightFactor: 1,
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('add-managed-category'),
            onPressed: _reordering ? null : () => _edit(),
            icon: const Icon(WicchuIcons.plus, size: 20),
            label: Text(context.tr('Add category')),
          ),
        ),
      ),
    ),
    body: FutureBuilder<List<CommunityCategory>>(
      future: _categories,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(child: Text(context.tr('No categories')));
        }
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.community.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'Drag the handle to reorder. Tap a category to edit.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_reordering) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                buildDefaultDragHandles: false,
                itemCount: items.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _reorder(items, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final category = items[index];
                  return Material(
                    key: ValueKey('managed-category-${category.id}'),
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: 64,
                          minLeadingWidth: 22,
                          leading: CategorySymbol(
                            category.icon,
                            size: 22,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            context.tr(category.name),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: _reordering ? null : () => _edit(category),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                enabled: !_reordering,
                                icon: const Icon(
                                  WicchuIcons.dotsThreeVertical,
                                  size: 20,
                                ),
                                tooltip: context.tr('Category options'),
                                onSelected: (value) => value == 'edit'
                                    ? _edit(category)
                                    : _delete(category),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(context.tr('Edit category')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      context.tr('Delete'),
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                enabled:
                                    !_reordering &&
                                    widget.repository
                                        is CategoryReorderRepository,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(
                                    WicchuIcons.dotsSixVertical,
                                    size: 20,
                                    semanticLabel: context.tr(
                                      'Reorder category',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index < items.length - 1)
                          Divider(
                            height: 1,
                            indent: 38,
                            color: theme.dividerColor,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _reorder(
    List<CommunityCategory> current,
    int oldIndex,
    int newIndex,
  ) async {
    if (_reordering || widget.repository is! CategoryReorderRepository) return;
    final reordered = [...current];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _reordering = true;
      _categories = Future.value(reordered);
    });
    try {
      final saved = await (widget.repository as CategoryReorderRepository)
          .reorderCategories(
            widget.community.id,
            reordered.map((item) => item.id).toList(growable: false),
          );
      if (mounted) {
        setState(() {
          _categories = Future.value(saved);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _categories = Future.value(current);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _edit([CommunityCategory? category]) async {
    if (_reordering) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CategoryEditor(
        category: category,
        community: widget.community,
        repository: widget.repository,
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(CommunityCategory category) async {
    if (_reordering) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete category?')),
        content: Text(
          context.tr(
            'Existing posts in {category} will remain, but the category will no longer be available.',
            {'category': context.tr(category.name)},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteCategory(widget.community.id, category.id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? context.tr(error.message)
                  : context.trError(error),
            ),
          ),
        );
      }
    }
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    this.category,
    required this.community,
    required this.repository,
  });
  final CommunityCategory? category;
  final Community community;
  final CommunityRepository repository;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _customEmojiController = TextEditingController();
  String? _displayName;
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late String _icon = widget.category?.icon ?? '💬';
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localized = widget.category == null
        ? ''
        : context.tr(widget.category!.name);
    // Refresh an untouched field when the language changes, preserving drafts.
    if (_displayName == null || _name.text == _displayName) {
      _name.text = localized;
    }
    _displayName = localized;
  }

  @override
  void dispose() {
    _customEmojiController.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.category == null) {
        await widget.repository.createCategory(
          widget.community.id,
          name: widget.category != null && _name.text.trim() == _displayName
              ? widget.category!.name
              : _name.text.trim(),
          description: _description.text.trim(),
          icon: _icon,
        );
      } else {
        await widget.repository.updateCategory(
          widget.community.id,
          widget.category!,
          name: widget.category != null && _name.text.trim() == _displayName
              ? widget.category!.name
              : _name.text.trim(),
          description: _description.text.trim(),
          icon: _icon,
        );
      }
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

  Widget _iconOption(String value, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    final selected = _icon == value;
    return Semantics(
      selected: selected,
      button: true,
      label: context.tr(categorySymbols[value]?.$1 ?? 'Current icon'),
      child: Tooltip(
        message: context.tr(categorySymbols[value]?.$1 ?? 'Current icon'),
        child: Material(
          color: selected ? colors.primaryContainer : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: InkWell(
            key: ValueKey('category-icon-$value'),
            borderRadius: BorderRadius.circular(12),
            onTap: _saving ? null : onTap,
            child: SizedBox.square(
              dimension: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CategorySymbol(
                    value,
                    color: selected ? colors.primary : colors.onSurface,
                  ),
                  if (selected)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      child: Icon(
                        WicchuIcons.check,
                        size: 12,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickIcon({bool customOnly = false}) async {
    var custom = '';
    _customEmojiController.clear();
    final form = GlobalKey<FormState>();
    bool showCustom = customOnly;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (pickerContext) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(customOnly ? 'Custom emoji' : 'Category icon'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (!customOnly)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in categorySymbols.keys)
                          _iconOption(
                            value,
                            () => Navigator.pop(pickerContext, value),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (!customOnly)
                    OutlinedButton.icon(
                      key: const ValueKey('category-other-icon'),
                      onPressed: () => update(() => showCustom = true),
                      icon: const Icon(WicchuIcons.plus, size: 18),
                      label: Text(context.tr('Other icon')),
                    ),
                  if (showCustom)
                    Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr(
                              'Type or paste an emoji, for example 🍔 or 🍕.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              width: 104,
                              child: TextFormField(
                                key: const ValueKey('category-custom-icon'),
                                controller: _customEmojiController,
                                onChanged: (value) =>
                                    update(() => custom = value),
                                maxLength: 1,
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: '☺',
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().characters.length == 1
                                    ? null
                                    : context.tr('Enter one emoji or symbol.'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final emoji in [
                                '🍔',
                                '🍕',
                                '🍟',
                                '🥤',
                                '🍰',
                                '🌮',
                              ])
                                Semantics(
                                  button: true,
                                  selected: custom == emoji,
                                  label: emoji,
                                  child: SizedBox.square(
                                    dimension: 48,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: custom == emoji
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                        side: BorderSide(
                                          color: custom == emoji
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => update(() {
                                        custom = emoji;
                                        _customEmojiController.text = emoji;
                                      }),
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: custom.trim().characters.length != 1
                                ? null
                                : () {
                                    if (form.currentState!.validate()) {
                                      Navigator.pop(
                                        pickerContext,
                                        custom.trim(),
                                      );
                                    }
                                  },
                            child: Text(context.tr('Apply')),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (mounted && result != null) setState(() => _icon = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = <String>{
      _icon,
      ...categorySymbols.keys.take(8),
    }.take(8);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              widget.category == null
                                  ? 'Add category'
                                  : 'Edit category',
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.community.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _name,
                            enabled: !_saving,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: context.tr('Name'),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? context.tr('Enter a category name.')
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _description,
                            enabled: !_saving,
                            minLines: 3,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: context.tr('Description (optional)'),
                              hintText: context.tr('Describe this category…'),
                              alignLabelWithHint: true,
                              isDense: true,
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('Category icon'),
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              TextButton(
                                onPressed: _saving ? null : _pickIcon,
                                child: Text(context.tr('See all')),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final value in suggestions)
                                _iconOption(
                                  value,
                                  () => setState(() => _icon = value),
                                ),
                              OutlinedButton.icon(
                                key: const ValueKey('category-add-custom-icon'),
                                onPressed: _saving
                                    ? null
                                    : () => _pickIcon(customOnly: true),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(WicchuIcons.plus, size: 20),
                                label: Text(context.tr('Other icon')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('Preview'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _name,
                            builder: (context, value, _) => ListTile(
                              key: const ValueKey('category-live-preview'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tileColor: theme.colorScheme.surfaceContainerLow,
                              leading: CategorySymbol(
                                _icon,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                value.text.trim().isEmpty
                                    ? context.tr('Name')
                                    : value.text.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(context.tr('Cancel')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(WicchuIcons.check),
                          label: Text(
                            context.tr(_saving ? 'Saving…' : 'Save changes'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MemberManagementPage extends StatefulWidget {
  const MemberManagementPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<MemberManagementPage> createState() => _MemberManagementPageState();
}

class _MemberManagementPageState extends State<MemberManagementPage> {
  late Future<List<CommunityMember>> _members = widget.repository.listMembers(
    widget.community.id,
    includeInactive: true,
  );

  void _reload() => setState(() {
    _members = widget.repository.listMembers(
      widget.community.id,
      includeInactive: true,
    );
  });

  bool _searching = false;
  String _query = '';
  String _sort = 'Newest';
  String _filter = 'All members';
  bool _showInviteHint = true;
  bool _showTip = true;

  String _rolePermissionDescription(CommunityRole role) {
    if (widget.community.isPublicProfile) {
      return switch (role) {
        CommunityRole.owner =>
          'Full control, ownership, financial support and team permissions.',
        CommunityRole.admin =>
          'Manages page content. The owner separately grants messages, orders, services and analytics.',
        CommunityRole.moderator =>
          'Reviews content, comments and reports. No financial or business access.',
        CommunityRole.member =>
          'Can follow and interact with the page. No management access.',
      };
    }
    return switch (role) {
      CommunityRole.owner =>
        'Full control, ownership, Community Rewards and administrator access.',
      CommunityRole.admin =>
        'Manages content, members, categories and community settings.',
      CommunityRole.moderator =>
        'Reviews content, comments and reports. No ownership or financial access.',
      CommunityRole.member =>
        'Can join, publish and interact according to community rules.',
    };
  }

  String _memberStatusLabel(CommunityMember member) => switch (member.status) {
    MembershipStatus.active => 'Active',
    MembershipStatus.pending => 'Pending',
    MembershipStatus.banned => 'Banned',
  };

  Future<void> _showRoleInformation(CommunityMember member) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(WicchuIcons.info),
      title: Text(dialogContext.tr(widget.community.roleLabel(member.role))),
      content: Text(dialogContext.tr(_rolePermissionDescription(member.role))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.tr('Close')),
        ),
      ],
    ),
  );

  List<String> _grantedPagePermissions(CommunityMember member) => [
    if (member.pageInboxAccess) 'Messages',
    if (member.canManageOrders) 'Orders',
    if (member.canManageServices) 'Services',
    if (member.canViewPageAnalytics) 'Page analytics',
  ];

  Widget _memberPill(
    String label, {
    required Color foreground,
    required Color background,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              context.tr(label),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: '${context.tr(label)}. ${context.tr('View role permissions')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: child,
      ),
    );
  }

  Future<void> _invite() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityInvitationsPage(
          community: widget.community,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _memberActions(CommunityMember member) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: UserAvatar(
                  name: member.name,
                  imageUrl: member.avatarUrl,
                ),
                title: Text(member.name),
                subtitle: Text(
                  context.tr(widget.community.roleLabel(member.role)),
                ),
              ),
              if (member.status == MembershipStatus.banned)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.tr('Reason shown to member')}: ${member.banPublicReason ?? context.tr('Community rules violation.')}',
                        ),
                        if (member.banInternalNote?.isNotEmpty == true)
                          Text(
                            '${context.tr('Internal moderator note')}: ${member.banInternalNote}',
                          ),
                        if (member.banExpiresAt != null)
                          Text(
                            '${context.tr('Access returns on')}: ${MaterialLocalizations.of(context).formatMediumDate(member.banExpiresAt!.toLocal())}',
                          ),
                      ],
                    ),
                  ),
                ),
              ListTile(
                leading: const Icon(WicchuIcons.user),
                title: Text(context.tr('View profile')),
                onTap: () => Navigator.pop(sheetContext, 'profile'),
              ),
              if (member.role != CommunityRole.owner) ...[
                if (member.status == MembershipStatus.active)
                  for (final role in [
                    CommunityRole.admin,
                    CommunityRole.moderator,
                    CommunityRole.member,
                  ])
                    if (role != CommunityRole.admin ||
                        widget.community.myRole == CommunityRole.owner)
                      ListTile(
                        leading: Icon(
                          role == member.role
                              ? WicchuIcons.checkCircleFill
                              : WicchuIcons.circle,
                        ),
                        title: Text(
                          role == CommunityRole.admin
                              ? context.tr(
                                  widget.community.isPublicProfile
                                      ? 'Invite as page administrator'
                                      : 'Invite as community administrator',
                                )
                              : context.tr('Set role: {role}', {
                                  'role': context.tr(
                                    widget.community.roleLabel(role),
                                  ),
                                }),
                        ),
                        subtitle: Text(
                          context.tr(_rolePermissionDescription(role)),
                        ),
                        enabled: role != member.role,
                        onTap: () =>
                            Navigator.pop(sheetContext, 'role:${role.name}'),
                      ),
                if (widget.community.isPublicProfile &&
                    widget.community.myRole == CommunityRole.owner &&
                    member.status == MembershipStatus.active &&
                    member.role == CommunityRole.admin)
                  ListTile(
                    leading: const Icon(WicchuIcons.key),
                    title: Text(context.tr('Page permissions')),
                    subtitle: Text(
                      context.tr(
                        'Choose access to messages, orders, services and analytics.',
                      ),
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, 'page-permissions'),
                  ),
                if (widget.community.myRole == CommunityRole.owner &&
                    member.status == MembershipStatus.active &&
                    member.role == CommunityRole.admin)
                  ListTile(
                    leading: const Icon(WicchuIcons.arrowsLeftRight),
                    title: Text(context.tr('Transfer ownership')),
                    onTap: () => Navigator.pop(sheetContext, 'transfer'),
                  ),
                if (widget.community.myRole == CommunityRole.owner &&
                    member.status == MembershipStatus.active &&
                    (member.role == CommunityRole.admin ||
                        member.role == CommunityRole.moderator))
                  ListTile(
                    leading: Icon(
                      WicchuIcons.shieldWarning,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      context.tr('Remove all management access'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      context.tr(
                        widget.community.isPublicProfile
                            ? 'Change this person back to a follower and remove every page permission.'
                            : 'Change this person back to a member and remove every management permission.',
                      ),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'remove-access'),
                  ),
                if (member.status == MembershipStatus.banned)
                  ListTile(
                    leading: const Icon(WicchuIcons.lockOpen),
                    title: Text(
                      context.tr(
                        widget.community.isPublicProfile
                            ? 'Unban follower'
                            : 'Unban member',
                      ),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'unban'),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(WicchuIcons.userMinus),
                    title: Text(
                      context.tr(
                        widget.community.isPublicProfile
                            ? 'Remove follower'
                            : 'Remove member',
                      ),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'remove'),
                  ),
                  ListTile(
                    leading: const Icon(WicchuIcons.prohibit),
                    title: Text(
                      context.tr(
                        widget.community.isPublicProfile
                            ? 'Ban follower'
                            : 'Ban member',
                      ),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'ban'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'profile') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberProfilePage(
            userId: member.userId,
            repository: widget.repository,
          ),
        ),
      );
    } else if (action.startsWith('role:')) {
      final role = CommunityRole.values.byName(action.substring(5));
      if (role == CommunityRole.admin) {
        await _inviteAdministrator(member);
      } else {
        await _setRole(member, role);
      }
    } else if (action == 'transfer') {
      await _transferOwnership(member);
    } else if (action == 'page-permissions') {
      await _setPagePermissions(member);
    } else if (action == 'remove-access') {
      await _removeAllAccess(member);
    } else {
      await _changeAccess(member, action);
    }
  }

  Future<void> _setPagePermissions(CommunityMember member) async {
    var messages = member.pageInboxAccess;
    var orders = member.canManageOrders;
    var services = member.canManageServices;
    var analytics = member.canViewPageAnalytics;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Page permissions')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Financial support, payouts, ownership transfers and team permissions always remain owner-only.',
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr('Permission presets'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: !messages && !orders && !services && !analytics
                      ? 'Content manager'
                      : messages && !orders && services && !analytics
                      ? 'Customer support'
                      : messages && orders && !services && analytics
                      ? 'Sales manager'
                      : !messages && !orders && !services && analytics
                      ? 'Analytics viewer'
                      : null,
                  onChanged: (preset) => setDialogState(() {
                    messages =
                        preset == 'Customer support' ||
                        preset == 'Sales manager';
                    orders = preset == 'Sales manager';
                    services = preset == 'Customer support';
                    analytics =
                        preset == 'Sales manager' ||
                        preset == 'Analytics viewer';
                  }),
                  child: Column(
                    children: [
                      for (final preset in [
                        'Content manager',
                        'Customer support',
                        'Sales manager',
                        'Analytics viewer',
                      ])
                        RadioListTile<String>(
                          value: preset,
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr(preset)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Presets only change the optional permissions below. Page administrators can still manage page content.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  value: messages,
                  onChanged: (value) =>
                      setDialogState(() => messages = value ?? false),
                  title: Text(context.tr('Messages')),
                  subtitle: Text(
                    context.tr('Read and reply from the shared page inbox.'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  value: orders,
                  onChanged: (value) =>
                      setDialogState(() => orders = value ?? false),
                  title: Text(context.tr('Orders')),
                  subtitle: Text(
                    context.tr('Manage the catalog and customer orders.'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  value: services,
                  onChanged: (value) =>
                      setDialogState(() => services = value ?? false),
                  title: Text(context.tr('Services')),
                  subtitle: Text(
                    context.tr(
                      'Manage service settings and customer requests.',
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.trailing,
                  value: analytics,
                  onChanged: (value) =>
                      setDialogState(() => analytics = value ?? false),
                  title: Text(context.tr('Page analytics')),
                  subtitle: Text(
                    context.tr('View page growth and engagement insights.'),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Save changes')),
            ),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      await widget.repository.setPagePermissions(
        widget.community.id,
        member.userId,
        messages: messages,
        orders: orders,
        services: services,
        analytics: analytics,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _removeAllAccess(CommunityMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          WicchuIcons.shieldWarning,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: Text(dialogContext.tr('Remove all management access?')),
        content: Text(
          dialogContext.tr(
            widget.community.isPublicProfile
                ? '{name} will become a follower. Messages, orders, services and analytics access will be removed immediately.'
                : '{name} will become a member and lose all administration and moderation access immediately.',
            {'name': member.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Remove access')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.setMemberRole(
        widget.community.id,
        member.userId,
        CommunityRole.member,
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Management access removed.'))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _inviteAdministrator(CommunityMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr(
            widget.community.isPublicProfile
                ? 'Invite as page administrator'
                : 'Invite as community administrator',
          ),
        ),
        content: Text(
          dialogContext.tr(
            widget.community.isPublicProfile
                ? '{name} will become a page administrator only after accepting the invitation.'
                : '{name} will become a community administrator only after accepting the invitation.',
            {'name': member.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Send invitation')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.createAdminInvitation(
        widget.community.id,
        member.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              widget.community.isPublicProfile
                  ? 'Page administrator invitation sent. The follower must accept it.'
                  : 'Community administrator invitation sent. The member must accept it.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _transferOwnership(CommunityMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Transfer ownership')),
        content: Text(
          dialogContext.tr(
            widget.community.isPublicProfile
                ? '{name} must accept the transfer. After acceptance, they will become the page owner and you will become a page administrator.'
                : '{name} must accept the transfer. After acceptance, they will become the community owner and you will become a community administrator.',
            {'name': member.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Send transfer')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.createOwnershipTransfer(
        widget.community.id,
        member.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Ownership transfer sent. The administrator must accept it.',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  String _memberLabel(String label) {
    if (!widget.community.isPublicProfile) return label;
    return switch (label) {
      'Search members' => 'Search followers',
      'Filter members' => 'Filter followers',
      'Sort members' => 'Sort followers',
      'All members' => 'All followers',
      'Active members' => 'Active followers',
      'No members match your search or filter.' =>
        'No followers match your search or filter.',
      _ => label,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(widget.community.isPublicProfile ? 'Followers' : 'Members'),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('Activity history'),
          icon: const Icon(WicchuIcons.clockCounterClockwise),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityAuditHistoryPage(
                community: widget.community,
                repository: widget.repository,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: context.tr(
            _searching ? 'Close' : _memberLabel('Search members'),
          ),
          icon: Icon(_searching ? WicchuIcons.x : WicchuIcons.magnifyingGlass),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _query = '';
          }),
        ),
        PopupMenuButton<String>(
          tooltip: context.tr(_memberLabel('Filter members')),
          initialValue: _filter,
          onSelected: (value) => setState(() => _filter = value),
          itemBuilder: (_) => [
            for (final value in ['All members', 'Active members', 'Banned'])
              CheckedPopupMenuItem(
                value: value,
                checked: _filter == value,
                child: Text(context.tr(_memberLabel(value))),
              ),
          ],
        ),
      ],
    ),
    body: FutureBuilder<List<CommunityMember>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.trError(snapshot.error!)),
                TextButton(
                  onPressed: _reload,
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          );
        }
        final all = snapshot.data ?? const <CommunityMember>[];
        final activeCount = all
            .where((m) => m.status == MembershipStatus.active)
            .length;
        final members = all
            .where(
              (m) =>
                  m.name.toLowerCase().contains(_query.trim().toLowerCase()) &&
                  (_filter == 'All members' ||
                      (_filter == 'Banned'
                          ? m.status == MembershipStatus.banned
                          : m.status == MembershipStatus.active)),
            )
            .toList();
        members.sort(
          (a, b) => _sort == 'Name'
              ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
              : b.joinedAt.compareTo(a.joinedAt),
        );
        final colors = Theme.of(context).colorScheme;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (_searching) ...[
              TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.tr(_memberLabel('Search members')),
                  prefixIcon: const Icon(WicchuIcons.magnifyingGlass),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.trCount(
                      activeCount,
                      singular: widget.community.isPublicProfile
                          ? '{count} follower'
                          : '{count} member',
                      plural: widget.community.isPublicProfile
                          ? '{count} followers'
                          : '{count} members',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _invite,
                  icon: const Icon(WicchuIcons.userPlus, size: 20),
                  label: Text(context.tr('Invite')),
                ),
              ],
            ),
            if (_showInviteHint && activeCount > 0) ...[
              const SizedBox(height: 16),
              _memberNotice(
                WicchuIcons.usersThree,
                'Invite more people',
                widget.community.isPublicProfile
                    ? 'Invite people to follow your page and discover your updates.'
                    : 'More neighbors, a better community.',
                () => setState(() => _showInviteHint = false),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.tr(_filter == 'All members' ? (widget.community.isPublicProfile ? 'Followers' : 'Members') : _memberLabel(_filter))} (${members.length})',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.tr(_memberLabel('Sort members')),
                  initialValue: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (_) => [
                    for (final value in ['Newest', 'Name'])
                      CheckedPopupMenuItem(
                        value: value,
                        checked: _sort == value,
                        child: Text(context.tr(_memberLabel(value))),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.tr(_sort),
                          style: TextStyle(color: colors.primary),
                        ),
                        const SizedBox(width: 8),
                        Icon(WicchuIcons.caretDown, color: colors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (members.isEmpty &&
                (activeCount > 0 ||
                    _query.isNotEmpty ||
                    _filter != 'All members'))
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    _memberLabel('No members match your search or filter.'),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final member in members)
              WicchuListTile.custom(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UserAvatar(
                              name: member.name,
                              imageUrl: member.avatarUrl,
                              radius: 24,
                            ),
                            if (member.isOnline &&
                                member.status == MembershipStatus.active)
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _memberPill(
                                    widget.community.roleLabel(member.role),
                                    foreground: colors.primary,
                                    background: colors.primary.withValues(
                                      alpha: .10,
                                    ),
                                    icon: WicchuIcons.info,
                                    onTap: () => _showRoleInformation(member),
                                  ),
                                  _memberPill(
                                    _memberStatusLabel(member),
                                    foreground:
                                        member.status == MembershipStatus.banned
                                        ? colors.error
                                        : member.status ==
                                              MembershipStatus.pending
                                        ? colors.tertiary
                                        : Colors.green.shade700,
                                    background:
                                        member.status == MembershipStatus.banned
                                        ? colors.errorContainer
                                        : member.status ==
                                              MembershipStatus.pending
                                        ? colors.tertiaryContainer
                                        : Colors.green.withValues(alpha: .10),
                                  ),
                                  if (widget.community.isPublicProfile &&
                                      member.role == CommunityRole.admin)
                                    for (final permission
                                        in _grantedPagePermissions(member))
                                      _memberPill(
                                        permission,
                                        foreground: colors.onSecondaryContainer,
                                        background: colors.secondaryContainer,
                                        icon: WicchuIcons.check,
                                      ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: ValueKey('member-actions-${member.userId}'),
                          tooltip: context.tr('Actions'),
                          onPressed: () => _memberActions(member),
                          icon: const Icon(WicchuIcons.dotsThreeVertical),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (activeCount == 0 &&
                _query.isEmpty &&
                _filter == 'All members') ...[
              const SizedBox(height: 40),
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: .07),
                      ),
                      child: Icon(
                        WicchuIcons.usersThree,
                        size: 88,
                        color: colors.primary,
                      ),
                    ),
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: colors.primary,
                      child: Icon(
                        WicchuIcons.plus,
                        color: colors.onPrimary,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  widget.community.isPublicProfile
                      ? 'Grow your page'
                      : 'Grow your community',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  widget.community.isPublicProfile
                      ? 'Invite people to follow your page and discover your updates.'
                      : 'Invite neighbors to start connecting and taking part.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Center(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                  onPressed: _invite,
                  icon: const Icon(WicchuIcons.userPlus),
                  label: Text(
                    context.tr(
                      widget.community.isPublicProfile
                          ? 'Invite followers'
                          : 'Invite members',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (_showTip && !widget.community.isPublicProfile) ...[
              const SizedBox(height: 20),
              _memberNotice(
                WicchuIcons.lightbulb,
                'Tip',
                'An active community is safer, friendlier and more useful for everyone.',
                () => setState(() => _showTip = false),
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _memberNotice(
    IconData icon,
    String title,
    String body,
    VoidCallback onClose,
  ) {
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
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(body),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Close'),
            onPressed: onClose,
            icon: const Icon(WicchuIcons.x, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _setRole(CommunityMember member, CommunityRole role) async {
    try {
      await widget.repository.setMemberRole(
        widget.community.id,
        member.userId,
        role,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _changeAccess(CommunityMember member, String action) async {
    String? reason;
    String? internalNote;
    DateTime? expiresAt;
    if (action == 'ban') {
      var publicReasonInput = '';
      var internalNoteInput = '';
      var durationDays = 0;
      final input = await showDialog<_BanInput>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              dialogContext.tr(
                widget.community.isPublicProfile
                    ? 'Ban follower'
                    : 'Ban member',
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    maxLength: 1000,
                    maxLines: 3,
                    onChanged: (value) => publicReasonInput = value,
                    decoration: InputDecoration(
                      labelText: dialogContext.tr('Reason shown to member'),
                      helperText: dialogContext.tr(
                        widget.community.isPublicProfile
                            ? 'The follower will receive this reason.'
                            : 'The member will receive this reason.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLength: 1000,
                    maxLines: 3,
                    onChanged: (value) => internalNoteInput = value,
                    decoration: InputDecoration(
                      labelText: dialogContext.tr(
                        'Internal moderator note (optional)',
                      ),
                      helperText: dialogContext.tr(
                        'Only community and Wicchu moderators can see this.',
                      ),
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: durationDays,
                    decoration: InputDecoration(
                      labelText: dialogContext.tr('Ban duration'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(dialogContext.tr('Permanent')),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(dialogContext.tr('1 day')),
                      ),
                      DropdownMenuItem(
                        value: 7,
                        child: Text(dialogContext.tr('7 days')),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text(dialogContext.tr('30 days')),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => durationDays = value ?? 0),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.tr('Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final value = publicReasonInput.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    _BanInput(value, internalNoteInput.trim(), durationDays),
                  );
                },
                child: Text(
                  dialogContext.tr(
                    widget.community.isPublicProfile
                        ? 'Ban follower'
                        : 'Ban member',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (input == null) return;
      reason = input.reason;
      internalNote = input.internalNote;
      if (input.durationDays > 0) {
        expiresAt = DateTime.now().toUtc().add(
          Duration(days: input.durationDays),
        );
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            dialogContext.tr(
              action == 'remove'
                  ? (widget.community.isPublicProfile
                        ? 'Remove follower'
                        : 'Remove member')
                  : (widget.community.isPublicProfile
                        ? 'Unban follower'
                        : 'Unban member'),
            ),
          ),
          content: Text(
            dialogContext.tr(
              action == 'remove'
                  ? (widget.community.isPublicProfile
                        ? 'This follower can follow the page again.'
                        : 'This member can request to join the community again.')
                  : (widget.community.isPublicProfile
                        ? 'This follower will regain access to the page.'
                        : 'This member will regain access to the community.'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                dialogContext.tr(action == 'remove' ? 'Remove' : 'Unban'),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await widget.repository.setMemberAccess(
        widget.community.id,
        member.userId,
        action: action,
        reason: reason,
        internalNote: internalNote,
        expiresAt: expiresAt,
      );
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                action == 'unban'
                    ? 'Member unbanned'
                    : action == 'remove'
                    ? 'Member removed'
                    : 'Member banned',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }
}

class CommunityAuditHistoryPage extends StatefulWidget {
  const CommunityAuditHistoryPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityAuditHistoryPage> createState() =>
      _CommunityAuditHistoryPageState();
}

class _CommunityAuditHistoryPageState extends State<CommunityAuditHistoryPage> {
  late Future<List<CommunityAuditEntry>> _history = widget.repository
      .listCommunityAuditHistory(widget.community.id);

  String _actionLabel(CommunityAuditEntry entry) => switch (entry.action) {
    'change_role' => 'Changed a role',
    'change_page_permissions' => 'Changed page permissions',
    'invite_admin' => 'Sent an administrator invitation',
    'transfer_ownership' => 'Sent an ownership transfer',
    'resend_invitation' => 'Sent an invitation again',
    'revoke_invitation' => 'Revoked an invitation',
    'remove_member' =>
      widget.community.isPublicProfile
          ? 'Removed a follower'
          : 'Removed a member',
    'ban_member' =>
      widget.community.isPublicProfile
          ? 'Banned a follower'
          : 'Banned a member',
    'unban_member' =>
      widget.community.isPublicProfile
          ? 'Unbanned a follower'
          : 'Unbanned a member',
    _ => 'Administrative action',
  };

  String? _details(CommunityAuditEntry entry) {
    if (entry.action == 'change_role') {
      final previous = entry.details['previousRole']?.toString();
      final next = entry.details['role']?.toString();
      if (previous != null && next != null) return '$previous → $next';
    }
    if (entry.action == 'change_page_permissions') {
      final permissions = entry.details['permissions'];
      if (permissions is Map) {
        final enabled = permissions.entries
            .where((item) => item.value == true)
            .map(
              (item) => context.tr(
                item.key.toString() == 'analytics'
                    ? 'Page analytics'
                    : '${item.key.toString()[0].toUpperCase()}${item.key.toString().substring(1)}',
              ),
            )
            .toList();
        return enabled.isEmpty
            ? context.tr('No additional permissions')
            : enabled.join(', ');
      }
    }
    return entry.reason.isEmpty ? null : entry.reason;
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }

  void _reload() => setState(() {
    _history = widget.repository.listCommunityAuditHistory(widget.community.id);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Activity history'))),
    body: FutureBuilder<List<CommunityAuditEntry>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.trError(snapshot.error!)),
                TextButton(
                  onPressed: _reload,
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const <CommunityAuditEntry>[];
        if (items.isEmpty) {
          return Center(
            child: Text(context.tr('No administrative activity yet.')),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final detail = _details(item);
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(WicchuIcons.shieldCheck),
                  ),
                  title: Text(context.tr(_actionLabel(item))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.targetName == null
                            ? item.actorName
                            : '${item.actorName} · ${item.targetName}',
                      ),
                      if (detail != null) Text(detail),
                      Text(_date(item.createdAt)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class _BanInput {
  const _BanInput(this.reason, this.internalNote, this.durationDays);

  final String reason;
  final String internalNote;
  final int durationDays;
}

class CommunitySettingsPage extends StatefulWidget {
  const CommunitySettingsPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunitySettingsPage> createState() => _CommunitySettingsPageState();
}

class _CommunitySettingsPageState extends State<CommunitySettingsPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.community.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.community.description,
  );
  late final TextEditingController _shortDescription = TextEditingController(
    text: widget.community.shortDescription,
  );
  late CommunityVisibility _visibility = widget.community.visibility;
  late bool _published = widget.community.published;
  late String _accentColor = widget.community.accentColor;
  late bool _neonBordersEnabled = widget.community.neonBordersEnabled;
  late NeonBorderAnimation _neonBorderAnimation =
      widget.community.neonBorderAnimation;
  late double _neonAnimationDurationSeconds =
      widget.community.neonAnimationDurationSeconds;
  late bool _headerBorderEnabled = widget.community.headerBorderEnabled;
  late Town _town = widget.community.town;

  late ProfileCategory? _profileCategory = widget.community.profileCategory;
  late final Set<BusinessService> _businessServices = {
    ...widget.community.businessServices,
  };
  late bool _approvalRequired = widget.community.approvalRequired;
  late bool _membersListVisible = widget.community.membersListVisible;
  late bool _showWeather = widget.community.showWeather;

  bool _showIdentityHelp = false;
  late final TextEditingController _businessAddress = TextEditingController(
    text: widget.community.businessLocation?.address ?? '',
  );
  late double? _businessLatitude = widget.community.businessLocation?.latitude;
  late double? _businessLongitude =
      widget.community.businessLocation?.longitude;
  late bool _showExactBusinessAddress =
      widget.community.businessLocation?.showExactAddress ?? false;
  late List<BusinessHour> _businessHours = [...widget.community.businessHours];
  late Set<BusinessFulfillmentOption> _businessFulfillmentOptions = {
    ...widget.community.businessFulfillmentOptions,
  };
  late BusinessContact _businessContact = widget.community.businessContact;

  late final List<CommunityLink> _links = [...widget.community.links];
  late String? _imageUrl = widget.community.imageUrl;
  String? _imageBlobName;
  Uint8List? _imagePreviewBytes;
  late String? _coverImageUrl = widget.community.coverImageUrl;
  String? _coverImageBlobName;
  Uint8List? _coverImagePreviewBytes;
  bool _editingName = false;
  bool _saving = false;
  bool _uploadingImage = false;
  bool? _anonymousInCommunity;
  bool _savingAnonymity = false;
  bool _anonymitySaved = false;
  bool _anonymityLoadFailed = false;

  late String _initialDraft = _draft;
  bool _allowPop = false;
  bool _confirmingLeave = false;

  String get _draft => jsonEncode([
    _name.text,
    _shortDescription.text,
    _description.text,
    _visibility.name,
    _published,
    _accentColor,
    _neonBordersEnabled,
    _neonBorderAnimation.apiValue,
    _neonAnimationDurationSeconds,
    _headerBorderEnabled,
    _town.id,
    _profileCategory?.name,
    _businessServices.map((value) => value.name).toList()..sort(),
    _approvalRequired,
    _membersListVisible,
    _showWeather,
    _businessAddress.text,
    _businessLatitude,
    _businessLongitude,
    _showExactBusinessAddress,
    _businessHours
        .map((hour) => [hour.day, hour.open, hour.close, hour.closed])
        .toList(),
    _businessFulfillmentOptions.map((value) => value.name).toList()..sort(),
    _businessContact.phone,
    _businessContact.whatsapp,
    _links.map((link) => [link.label, link.url]).toList(),
    _imageUrl,
    _coverImageUrl,
  ]);

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _leave() async {
    if (_saving || _uploadingImage || _confirmingLeave) return;
    if (_draft != _initialDraft) {
      _confirmingLeave = true;
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('Unsaved changes')),
          content: Text(context.tr('Save your changes before leaving?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'stay'),
              child: Text(context.tr('Keep editing')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'discard'),
              child: Text(context.tr('Discard')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: Text(context.tr('Save changes')),
            ),
          ],
        ),
      );
      _confirmingLeave = false;
      if (!mounted) return;
      if (choice == 'save') {
        await _save();
        return;
      }
      if (choice != 'discard') return;
    }
    _close();
  }

  void _close([Community? result]) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  @override
  void initState() {
    super.initState();
    _initialDraft = _draft;
    for (final controller in [
      _name,
      _shortDescription,
      _description,
      _businessAddress,
    ]) {
      controller.addListener(_draftChanged);
    }

    _loadAnonymity();
  }

  @override
  void dispose() {
    _name.dispose();
    _shortDescription.dispose();
    _description.dispose();
    _businessAddress.dispose();
    super.dispose();
  }

  Widget _settingsDivider() => Divider(
    height: 16,
    thickness: .5,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .4),
  );

  Widget _settingsSection(String title, IconData icon, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.tr(title),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...children,
          ],
        ),
      );

  Future<void> _editFullDescription() async {
    if (_saving || _uploadingImage) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (editorContext) => Scaffold(
          appBar: AppBar(
            title: Text(context.tr('About')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(editorContext),
                child: Text(context.tr('Done')),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const ValueKey('community-full-description'),
                controller: _description,
                autofocus: true,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                maxLength: CommunityInputLimits.description,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: InputDecoration(
                  labelText: context.tr('About'),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _photoActions({required bool cover}) async {
    if (_saving || _uploadingImage) return;
    final hasPhoto = cover ? _coverImageUrl != null : _imageUrl != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(WicchuIcons.camera),
              title: Text(
                context.tr(cover ? 'Change cover photo' : 'Change photo'),
              ),
              onTap: () => Navigator.pop(sheetContext, 'change'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(WicchuIcons.trash),
                title: Text(
                  context.tr(cover ? 'Remove cover photo' : 'Remove photo'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || _saving || _uploadingImage) return;
    if (action == 'change') await _pickImage(cover: cover);
    if (action == 'remove') {
      setState(() {
        if (cover) {
          _coverImageUrl = null;
          _coverImageBlobName = '';
          _coverImagePreviewBytes = null;
        } else {
          _imageUrl = null;
          _imageBlobName = '';
          _imagePreviewBytes = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        _allowPop || (!_saving && !_uploadingImage && _draft == _initialDraft),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(
          context.tr(
            widget.community.isPublicProfile
                ? (_profileCategory == ProfileCategory.localBusiness
                      ? 'Business settings'
                      : 'Profile settings')
                : 'Edit community',
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('community-settings-save'),
            onPressed: _saving || _uploadingImage || _draft == _initialDraft
                ? null
                : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('Save')),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    if (_coverImageUrl != null)
                      _coverImagePreviewBytes != null
                          ? Image.memory(
                              _coverImagePreviewBytes!,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              _coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(WicchuIcons.mountains, size: 32),
                            ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IconButton.filledTonal(
                        key: const ValueKey('edit-community-cover'),
                        onPressed: _uploadingImage || _saving
                            ? null
                            : () => _photoActions(cover: true),
                        icon: const Icon(WicchuIcons.camera, size: 18),
                        tooltip: context.tr('Change cover photo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InkWell(
                          onTap: _saving || _uploadingImage
                              ? null
                              : () => _photoActions(cover: false),
                          child: ClipOval(
                            child: SizedBox.square(
                              dimension: 64,
                              child: _imageUrl == null
                                  ? ColoredBox(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      child: Icon(
                                        !widget.community.isPublicProfile
                                            ? WicchuIcons.usersThree
                                            : _profileCategory ==
                                                  ProfileCategory.localBusiness
                                            ? WicchuIcons.storefront
                                            : _profileCategory ==
                                                  ProfileCategory.organization
                                            ? WicchuIcons.buildings
                                            : WicchuIcons.user,
                                        size: 30,
                                      ),
                                    )
                                  : _imagePreviewBytes != null
                                  ? Image.memory(
                                      _imagePreviewBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      _imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => ColoredBox(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.errorContainer,
                                        child: const Icon(
                                          WicchuIcons.imageBroken,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -8,
                          bottom: -8,
                          child: IconButton.filled(
                            tooltip: context.tr(
                              widget.community.isPublicProfile
                                  ? 'Change page photo'
                                  : 'Change community photo',
                            ),
                            onPressed: _uploadingImage || _saving
                                ? null
                                : () => _photoActions(cover: false),
                            icon: _uploadingImage
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(WicchuIcons.camera),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _name,
                              builder: (context, value, _) => Text(
                                value.text,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('Edit name'),
                            onPressed: _saving
                                ? null
                                : () => setState(
                                    () => _editingName = !_editingName,
                                  ),
                            icon: const Icon(WicchuIcons.pencilSimple),
                          ),
                        ],
                      ),
                      Text(
                        context.tr(widget.community.spaceTypeLabel),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_editingName)
              TextFormField(
                controller: _name,
                maxLength: CommunityInputLimits.name,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr(
                        widget.community.isPublicProfile
                            ? 'Add a page name.'
                            : 'Add a community name.',
                      )
                    : value.characters.length > CommunityInputLimits.name
                    ? context.tr('Use at most {count} characters.', {
                        'count': '${CommunityInputLimits.name}',
                      })
                    : null,
                decoration: InputDecoration(labelText: context.tr('Name')),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortDescription,
              maxLength: CommunityInputLimits.shortDescription,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) =>
                  (value ?? '').characters.length >
                      CommunityInputLimits.shortDescription
                  ? context.tr('Use at most {count} characters.', {
                      'count': '${CommunityInputLimits.shortDescription}',
                    })
                  : null,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr('Short description'),
                helperText: context.tr('Shown near the top of the profile.'),
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLength: CommunityInputLimits.description,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) =>
                  (value ?? '').characters.length >
                      CommunityInputLimits.description
                  ? context.tr('Use at most {count} characters.', {
                      'count': '${CommunityInputLimits.description}',
                    })
                  : null,
              minLines: 4,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.tr('About'),
                helper: Text(
                  context.tr(
                    widget.community.isPublicProfile
                        ? 'Visible in profile information'
                        : 'Visible in community information',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _saving || _uploadingImage
                    ? null
                    : _editFullDescription,
                child: Text(context.tr('Edit full description')),
              ),
            ),
            _settingsSection('Appearance', WicchuIcons.palette, [
              for (final section in const [
                PageAppearanceSection.color,
                PageAppearanceSection.neon,
              ])
                ListTile(
                  key: ValueKey('appearance-${section.name}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    section == PageAppearanceSection.color
                        ? WicchuIcons.palette
                        : WicchuIcons.sparkle,
                  ),
                  title: Text(context.tr(section.title)),
                  subtitle: Text(
                    context.tr(switch (section) {
                      PageAppearanceSection.color => profileAccentLabel(
                        _accentColor,
                      ),
                      PageAppearanceSection.neon =>
                        _neonBordersEnabled ? 'On' : 'Off',
                      PageAppearanceSection.border =>
                        _headerBorderEnabled ? 'On' : 'Off',
                    }),
                  ),
                  trailing: const Icon(WicchuIcons.caretRight),
                  onTap: _saving ? null : () => _openAppearance(section),
                ),
            ]),
            const SizedBox(height: 12),
            _settingsSection('Information', WicchuIcons.info, [
              if (widget.community.isPublicProfile) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(WicchuIcons.storefront),
                  title: Text(context.tr('Profile type and services')),
                  subtitle: Text(
                    [
                      context.tr(
                        (_profileCategory ?? ProfileCategory.localBusiness)
                            .label,
                      ),
                      if (_profileCategory == ProfileCategory.localBusiness)
                        ..._businessServices.map(
                          (service) => context.tr(service.label),
                        ),
                    ].join(' · '),
                  ),
                  trailing: const Icon(WicchuIcons.caretRight),
                  onTap: _saving ? null : _openBusinessServices,
                ),
                _settingsDivider(),
              ],
              if (widget.community.isPublicProfile &&
                  _profileCategory == ProfileCategory.localBusiness) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(WicchuIcons.storefront),
                  title: Text(context.tr('Business operations')),
                  subtitle: Text(
                    context.tr(
                      'Opening hours, contact and fulfillment options',
                    ),
                  ),
                  trailing: const Icon(WicchuIcons.caretRight),
                  onTap: _saving ? null : _openRestaurantSettings,
                ),
                _settingsDivider(),
              ],
              ListTile(
                key: const ValueKey('page-location-settings'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(WicchuIcons.mapPin),
                title: Text(context.tr('Location')),
                subtitle: Text(
                  widget.community.isGlobal
                      ? context.tr('Open to people everywhere')
                      : '${_town.name} · ${_town.countryCode}',
                ),
                trailing: const Icon(WicchuIcons.caretRight),
                onTap: _saving || widget.community.isGlobal
                    ? null
                    : _openLocationSettings,
              ),
            ]),
            const SizedBox(height: 12),
            if (!widget.community.isPublicProfile ||
                _profileCategory != ProfileCategory.localBusiness) ...[
              _settingsSection('Posts and content', WicchuIcons.article, [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('Require post approval')),
                  value: _approvalRequired,
                  onChanged: (value) =>
                      setState(() => _approvalRequired = value),
                ),
              ]),
              if (!widget.community.isGlobal)
                _settingsSection('Additional information', WicchuIcons.info, [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(WicchuIcons.cloud),
                    title: Text(context.tr('Show local weather')),
                    subtitle: Text(
                      context.tr(
                        'Display current conditions for the community town.',
                      ),
                    ),
                    value: _showWeather,
                    onChanged: (value) => setState(() => _showWeather = value),
                  ),
                ]),
            ],
            const SizedBox(height: 8),
            _settingsSection('Content', WicchuIcons.linkSimple, [
              if (widget.community.myRole == CommunityRole.owner ||
                  widget.community.myRole == CommunityRole.admin) ...[
                ListTile(
                  key: const ValueKey('settings-edit-categories'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(WicchuIcons.shapes),
                  title: Text(context.tr('Edit categories')),
                  trailing: const Icon(WicchuIcons.caretRight),
                  onTap: _saving
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryManagementPage(
                              community: widget.community,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                ),
                _settingsDivider(),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(WicchuIcons.linkSimple),
                title: Text(context.tr('Official links')),
                subtitle: Text(
                  context.tr(
                    'Add a website, social network, contact page, or another official link.',
                  ),
                ),
                trailing: const Icon(WicchuIcons.caretRight),
                onTap: _saving ? null : _openOfficialLinks,
              ),
              _settingsDivider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(WicchuIcons.listChecks),
                title: Text(context.tr('Community rules')),
                trailing: const Icon(WicchuIcons.caretRight),
                onTap: _saving
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RuleManagementPage(
                            community: widget.community,
                            repository: widget.repository,
                          ),
                        ),
                      ),
              ),
            ]),
            _settingsSection('Privacy', WicchuIcons.shieldWarning, [
              _compactPrivacySetting(
                title: 'Hide my identity',
                description:
                    'When enabled, members will see “Community Admin” instead of your name and photo in this community. Other administrators can still identify you.',
                extraHelp: 'This setting saves automatically.',
                value: _anonymousInCommunity ?? false,
                onChanged: _anonymousInCommunity == null || _savingAnonymity
                    ? null
                    : _setAnonymity,
                expanded: _showIdentityHelp,
                onHelp: () =>
                    setState(() => _showIdentityHelp = !_showIdentityHelp),
                status: _anonymityLoadFailed
                    ? IconButton(
                        tooltip: context.tr('Retry'),
                        onPressed: _loadAnonymity,
                        icon: const Icon(WicchuIcons.arrowsClockwise, size: 18),
                      )
                    : _savingAnonymity || _anonymousInCommunity == null
                    ? Semantics(
                        label: context.tr(
                          _savingAnonymity ? 'Saving…' : 'Loading…',
                        ),
                        liveRegion: true,
                        child: const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Tooltip(
                        message: context.tr(
                          _anonymitySaved
                              ? 'Saved automatically'
                              : 'This setting saves automatically.',
                        ),
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(
                          _anonymitySaved
                              ? WicchuIcons.checkCircle
                              : WicchuIcons.cloudCheck,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ]),
            const SizedBox(height: 16),
            _settingsSection('General', WicchuIcons.gearSix, [
              if (widget.community.isPublicProfile)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    _published ? WicchuIcons.globe : WicchuIcons.eyeSlash,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(context.tr('Page is published')),
                  subtitle: Text(
                    context.tr(
                      _published
                          ? 'This page is visible in search, Explore and public feeds.'
                          : 'Only owners and administrators can find and edit this page.',
                    ),
                  ),
                  value: _published,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _published = value),
                )
              else ...[
                Row(
                  children: [
                    Icon(
                      _visibility == CommunityVisibility.public
                          ? WicchuIcons.globe
                          : WicchuIcons.lockKey,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.tr('Visibility'))),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<CommunityVisibility>(
                        value: _visibility,
                        borderRadius: BorderRadius.circular(12),
                        icon: const Icon(WicchuIcons.caretDown),
                        items: [
                          for (final value in CommunityVisibility.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(context.tr(value.name)),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _visibility = value ?? _visibility,
                              ),
                      ),
                    ),
                  ],
                ),
                _settingsDivider(),
                SwitchListTile.adaptive(
                  key: const ValueKey('members-list-visibility-setting'),
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    _membersListVisible
                        ? WicchuIcons.usersThree
                        : WicchuIcons.eyeSlash,
                  ),
                  title: Text(context.tr('Show member list')),
                  subtitle: Text(
                    context.tr(
                      _membersListVisible
                          ? 'Members can see who belongs to this community.'
                          : 'Only administrators and moderators can view the member list.',
                    ),
                  ),
                  value: _membersListVisible,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _membersListVisible = value),
                ),
              ],
            ]),
          ],
        ),
      ),
    ),
  );

  Widget _compactPrivacySetting({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required bool expanded,
    required VoidCallback onHelp,
    String? extraHelp,
    Widget? status,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.tr(title),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (status != null) ...[const SizedBox(width: 8), status],
          Semantics(
            expanded: expanded,
            child: IconButton(
              tooltip:
                  '${context.tr(expanded ? 'Hide details' : 'More information')}: ${context.tr(title)}',
              onPressed: onHelp,
              icon: Icon(
                expanded ? WicchuIcons.infoFill : WicchuIcons.info,
                size: 20,
              ),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Semantics(
            label: context.tr(title),
            child: Switch.adaptive(value: value, onChanged: onChanged),
          ),
        ],
      ),
      if (expanded)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${context.tr(description)}${extraHelp == null ? '' : '\n${context.tr(extraHelp)}'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ],
  );

  Future<void> _save() async {
    if (_saving || _uploadingImage || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateCommunity(
        widget.community,
        town: _town,
        profileCategory: _profileCategory,
        businessServices: _profileCategory == ProfileCategory.localBusiness
            ? List.unmodifiable(_businessServices)
            : const [],
        name: _name.text.trim(),
        shortDescription: _shortDescription.text.trim(),
        description: _description.text.trim(),
        visibility: _visibility,
        approvalRequired: _approvalRequired,
        membersListVisible: _membersListVisible,
        showWeather: _showWeather,
        links: List.unmodifiable(_links),
        businessLocation:
            _businessAddress.text.trim().isEmpty && _businessLatitude == null
            ? null
            : BusinessLocation(
                address: _businessAddress.text.trim(),
                latitude: _businessLatitude,
                longitude: _businessLongitude,
                showExactAddress: _showExactBusinessAddress,
              ),
        businessHours: _profileCategory == ProfileCategory.localBusiness
            ? List.unmodifiable(_businessHours)
            : null,
        businessFulfillmentOptions:
            _profileCategory == ProfileCategory.localBusiness
            ? List.unmodifiable(_businessFulfillmentOptions)
            : null,
        businessContact: _profileCategory == ProfileCategory.localBusiness
            ? _businessContact
            : null,
        imageUrl: _imageUrl,
        imageBlobName: _imageBlobName,
        coverImageUrl: _coverImageUrl,
        coverImageBlobName: _coverImageBlobName,
        published: widget.community.isPublicProfile ? _published : null,
        accentColor: _accentColor,
        neonBordersEnabled: _neonBordersEnabled,
        neonBorderAnimation: _neonBorderAnimation,
        neonAnimationDurationSeconds: _neonAnimationDurationSeconds,
        headerBorderEnabled:
            _headerBorderEnabled != widget.community.headerBorderEnabled
            ? _headerBorderEnabled
            : null,
      );
      if (!mounted) return;
      if (updated.headerBorderEnabled != _headerBorderEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'The decorative border setting could not be saved. Please try again later.',
              ),
            ),
          ),
        );
        return;
      }
      if (widget.community.isPublicProfile &&
          _profileCategory != null &&
          updated.profileCategory != _profileCategory) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Your changes were saved, but the profile category could not be saved. Please try again later.',
              ),
            ),
          ),
        );
        return;
      }
      _close(updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadAnonymity() async {
    setState(() => _anonymityLoadFailed = false);
    try {
      final value = await widget.repository.getAdminAnonymity(
        widget.community.id,
      );
      if (mounted) setState(() => _anonymousInCommunity = value);
    } catch (error) {
      if (mounted) {
        setState(() => _anonymityLoadFailed = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _setAnonymity(bool value) async {
    final previous = _anonymousInCommunity ?? false;
    setState(() {
      _anonymousInCommunity = value;
      _savingAnonymity = true;
      _anonymitySaved = false;
    });
    try {
      final saved = await widget.repository.updateAdminAnonymity(
        widget.community.id,
        anonymousInCommunity: value,
      );
      if (mounted) {
        setState(() {
          _anonymousInCommunity = saved;
          _anonymitySaved = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _anonymousInCommunity = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingAnonymity = false);
    }
  }

  Future<void> _openLocationSettings() async {
    final result = await Navigator.push<PageLocationDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => PageLocationSettingsPage(
          community: widget.community,
          repository: widget.repository,
          initial: PageLocationDraft(
            _town,
            _businessAddress.text,
            _businessLatitude,
            _businessLongitude,
            _showExactBusinessAddress,
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _town = result.town;
      _businessAddress.text = result.address;
      _businessLatitude = result.latitude;
      _businessLongitude = result.longitude;
      _showExactBusinessAddress = result.showExactAddress;
    });
  }

  Future<void> _openAppearance(PageAppearanceSection section) async {
    final draft = await Navigator.push<PageAppearanceDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => PageAppearanceEditor(
          section: section,
          value: (
            accent: _accentColor,
            neon: _neonBordersEnabled,
            border: _headerBorderEnabled,
            animation: _neonBorderAnimation,
            duration: _neonAnimationDurationSeconds,
          ),
        ),
      ),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _accentColor = draft.accent;
      _neonBordersEnabled = draft.neon;
      _headerBorderEnabled = draft.border;
      _neonBorderAnimation = draft.animation;
      _neonAnimationDurationSeconds = draft.duration;
    });
  }

  Future<void> _openBusinessServices() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessServicesPage(
          profileCategory: _profileCategory ?? ProfileCategory.localBusiness,
          onProfileCategoryChanged: (category) {
            if (mounted) setState(() => _profileCategory = category);
          },
          services: _businessServices,
          onChanged: (services) {
            if (!mounted) return;
            setState(() {
              _businessServices
                ..clear()
                ..addAll(services);
            });
          },
        ),
      ),
    );
  }

  Future<void> _openRestaurantSettings() async {
    final result = await Navigator.push<RestaurantSettingsDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantSettingsPage(
          hours: _businessHours,
          fulfillmentOptions: _businessFulfillmentOptions.toList(),
          contact: _businessContact,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _businessHours = result.hours;
      _businessFulfillmentOptions = result.fulfillmentOptions.toSet();
      _businessContact = result.contact;
    });
  }

  Future<void> _openOfficialLinks() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OfficialLinksPage(
          links: _links,
          onChanged: (links) {
            if (!mounted) return;
            setState(() {
              _links
                ..clear()
                ..addAll(links);
            });
          },
        ),
      ),
    );
  }

  Future<void> _pickImage({required bool cover}) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null || !mounted) return;
    if (!isWithinMediaUploadLimit(await file.length())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('The file must be under 25 MB.'))),
        );
      }
      return;
    }
    setState(() => _uploadingImage = true);
    try {
      final prepared = await preparePostImage(
        await file.readAsBytes(),
        file.name,
      );
      if (!isWithinMediaUploadLimit(prepared.bytes.length)) {
        throw const FormatException('The file must be under 25 MB.');
      }
      final media = await widget.repository.uploadPostMedia(
        bytes: prepared.bytes,
        filename: prepared.filename,
        mimeType: prepared.mimeType,
      );
      if (media.type != 'image') {
        throw Exception('Choose a supported image file.');
      }
      if (!mounted) return;
      setState(() {
        if (cover) {
          _coverImageUrl = media.url;
          _coverImageBlobName = media.blobName;
          _coverImagePreviewBytes = prepared.bytes;
        } else {
          _imageUrl = media.url;
          _imageBlobName = media.blobName;
          _imagePreviewBytes = prepared.bytes;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }
}
