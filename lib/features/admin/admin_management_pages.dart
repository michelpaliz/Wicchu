import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_input_limits.dart';
import 'package:flutter/services.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'rule_management_page.dart';
import '../community/community_invitations_page.dart';
import '../community/user_avatar.dart';
import '../profile/member_profile_page.dart';

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

  void _reload() => setState(() {
    _categories = widget.repository.listCategories(widget.community.id);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Categories'))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: Text(context.tr('Add category')),
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
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final theme = Theme.of(context);
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                        'Organize conversations in your community. Tap a category to edit it.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            final category = items[index - 1];
            return Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                title: Text(
                  context.tr(category.name),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: category.description.isEmpty
                    ? null
                    : Text(
                        category.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => _edit(category),
                trailing: PopupMenuButton<String>(
                  tooltip: context.tr('Category options'),
                  onSelected: (value) =>
                      value == 'edit' ? _edit(category) : _delete(category),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.tr('Edit category')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.tr('Delete'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
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

  Future<void> _edit([CommunityCategory? category]) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SafeArea(
            top: false,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('Category icon'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in {
                        '💬': 'General',
                        '📰': 'News',
                        '📅': 'Events',
                        '🏠': 'Housing',
                        '💼': 'Jobs',
                        '⚽': 'Sports',
                        '🛒': 'Marketplace',
                        '📍': 'Local Businesses',
                        '🔎': 'Lost & Found',
                        '🌿': 'Nature',
                        '🐾': 'Pets',
                        '📢': 'Announcements',
                        if (!const [
                          '💬',
                          '📰',
                          '📅',
                          '🏠',
                          '💼',
                          '⚽',
                          '🛒',
                          '📍',
                          '🔎',
                          '🌿',
                          '🐾',
                          '📢',
                        ].contains(_icon))
                          _icon: 'Current icon',
                      }.entries)
                        Semantics(
                          label: context.tr(option.value),
                          selected: _icon == option.key,
                          button: true,
                          child: Tooltip(
                            message: context.tr(option.value),
                            child: ChoiceChip(
                              key: ValueKey('category-icon-${option.key}'),
                              label: Text(
                                option.key,
                                style: const TextStyle(fontSize: 23),
                              ),
                              selected: _icon == option.key,
                              showCheckmark: true,
                              selectedColor: theme.colorScheme.primaryContainer,
                              side: BorderSide.none,
                              onSelected: _saving
                                  ? null
                                  : (_) => setState(() => _icon = option.key),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('Name'),
                      helperText: context.tr('Choose a short, clear name.'),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.tr('Enter a category name.')
                        : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _description,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.tr('Description (optional)'),
                      hintText: context.tr('What should neighbors post here?'),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(context.tr('Cancel')),
                      ),
                      const SizedBox(width: 16),
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
                              : const Icon(Icons.check),
                          label: Text(
                            context.tr(_saving ? 'Saving…' : 'Save changes'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                  context.tr(
                    member.role == CommunityRole.owner
                        ? 'Owner'
                        : member.role.name,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
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
                    ListTile(
                      leading: Icon(
                        role == member.role
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                      ),
                      title: Text(
                        context.tr('Set role: {role}', {
                          'role': context.tr(role.name),
                        }),
                      ),
                      enabled: role != member.role,
                      onTap: () =>
                          Navigator.pop(sheetContext, 'role:${role.name}'),
                    ),
                if (member.status == MembershipStatus.banned)
                  ListTile(
                    leading: const Icon(Icons.lock_open),
                    title: Text(context.tr('Unban member')),
                    onTap: () => Navigator.pop(sheetContext, 'unban'),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined),
                    title: Text(context.tr('Remove member')),
                    onTap: () => Navigator.pop(sheetContext, 'remove'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: Text(context.tr('Ban member')),
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
      await _setRole(member, CommunityRole.values.byName(action.substring(5)));
    } else {
      await _changeAccess(member, action);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Members')),
      actions: [
        IconButton(
          tooltip: context.tr(_searching ? 'Close' : 'Search members'),
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _query = '';
          }),
        ),
        PopupMenuButton<String>(
          tooltip: context.tr('Filter members'),
          initialValue: _filter,
          onSelected: (value) => setState(() => _filter = value),
          itemBuilder: (_) => [
            for (final value in ['All members', 'Active members', 'Banned'])
              CheckedPopupMenuItem(
                value: value,
                checked: _filter == value,
                child: Text(context.tr(value)),
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
                  hintText: context.tr('Search members'),
                  prefixIcon: const Icon(Icons.search),
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
                      singular: '{count} member',
                      plural: '{count} members',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _invite,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  label: Text(context.tr('Invite')),
                ),
              ],
            ),
            if (_showInviteHint) ...[
              const SizedBox(height: 16),
              _memberNotice(
                Icons.groups_outlined,
                'Invite more people',
                'More neighbors, a better community.',
                () => setState(() => _showInviteHint = false),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.tr(_filter == 'All members' ? 'Members' : _filter)} (${members.length})',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.tr('Sort members'),
                  initialValue: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (_) => [
                    for (final value in ['Newest', 'Name'])
                      CheckedPopupMenuItem(
                        value: value,
                        checked: _sort == value,
                        child: Text(context.tr(value)),
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
                        Icon(Icons.expand_more, color: colors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr('No members match your search or filter.'),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final member in members)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colors.onSurface.withValues(alpha: .06),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: Stack(
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
                  title: Text(member.name),
                  subtitle: Text(
                    context.tr(
                      member.status == MembershipStatus.banned
                          ? 'Banned'
                          : member.status == MembershipStatus.pending
                          ? 'Pending'
                          : member.isOnline
                          ? 'Online now'
                          : member.lastActiveAt != null
                          ? 'Active recently'
                          : 'Offline',
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          context.tr(
                            member.role == CommunityRole.owner
                                ? 'Owner'
                                : member.role.name,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () => _memberActions(member),
                ),
              ),
            if (activeCount <= 1 &&
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
                        Icons.groups_rounded,
                        size: 88,
                        color: colors.primary,
                      ),
                    ),
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: colors.primary,
                      child: Icon(Icons.add, color: colors.onPrimary, size: 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('Grow your community'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Invite neighbors to start connecting and taking part.',
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
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(context.tr('Invite members')),
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (_showTip) ...[
              const SizedBox(height: 20),
              _memberNotice(
                Icons.lightbulb_outline,
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
            icon: const Icon(Icons.close, size: 18),
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
    if (action == 'ban') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.tr('Ban member')),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            maxLines: 3,
            decoration: InputDecoration(labelText: dialogContext.tr('Reason')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: Text(dialogContext.tr('Ban member')),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            dialogContext.tr(
              action == 'remove' ? 'Remove member' : 'Unban member',
            ),
          ),
          content: Text(
            dialogContext.tr(
              action == 'remove'
                  ? 'This member can request to join the community again.'
                  : 'This member will regain access to the community.',
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
  late CommunityVisibility _visibility = widget.community.visibility;
  late bool _approvalRequired = widget.community.approvalRequired;
  late bool _showWeather = widget.community.showWeather;
  late final List<CommunityLink> _links = [...widget.community.links];
  late String? _imageUrl = widget.community.imageUrl;
  String? _imageBlobName;
  bool _saving = false;
  bool _uploadingImage = false;
  bool? _anonymousInCommunity;
  bool _savingAnonymity = false;
  bool _anonymitySaved = false;
  bool _anonymityLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAnonymity();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Community settings'))),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 80,
                    child: _imageUrl == null
                        ? ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: const Icon(Icons.groups_outlined, size: 48),
                          )
                        : Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: IconButton.filled(
                    tooltip: context.tr('Change community photo'),
                    onPressed: _uploadingImage ? null : _pickImage,
                    icon: _uploadingImage
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                  ),
                ),
              ],
            ),
          ),
          if (_imageUrl != null)
            TextButton(
              onPressed: _uploadingImage
                  ? null
                  : () => setState(() {
                      _imageUrl = null;
                      _imageBlobName = '';
                    }),
              child: Text(context.tr('Remove photo')),
            ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            maxLength: CommunityInputLimits.name,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => value == null || value.trim().isEmpty
                ? context.tr('Add a community name.')
                : value.characters.length > CommunityInputLimits.name
                ? context.tr('Use at most {count} characters.', {
                    'count': '${CommunityInputLimits.name}',
                  })
                : null,
            decoration: InputDecoration(labelText: context.tr('Name')),
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
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: context.tr('Description')),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CommunityVisibility>(
            initialValue: _visibility,
            decoration: InputDecoration(labelText: context.tr('Visibility')),
            items: CommunityVisibility.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(context.tr(value.name)),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _visibility = value ?? _visibility),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Require post approval')),
            value: _approvalRequired,
            onChanged: (value) => setState(() => _approvalRequired = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.cloud_outlined),
            title: Text(context.tr('Show local weather')),
            subtitle: Text(
              context.tr('Display current conditions for the community town.'),
            ),
            value: _showWeather,
            onChanged: (value) => setState(() => _showWeather = value),
          ),
          const SizedBox(height: 20),
          Material(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Your identity in this community'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('Hide my identity from members')),
                    value: _anonymousInCommunity ?? false,
                    onChanged: _anonymousInCommunity == null || _savingAnonymity
                        ? null
                        : _setAnonymity,
                  ),
                  Text(
                    context.tr(
                      'When enabled, members will see “Community Admin” instead of your name and photo in this community. Other administrators can still identify you.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_anonymityLoadFailed)
                    TextButton.icon(
                      onPressed: _loadAnonymity,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.tr('Retry')),
                    )
                  else
                    Row(
                      children: [
                        if (_savingAnonymity || _anonymousInCommunity == null)
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _anonymitySaved
                                ? Icons.check_circle_outline
                                : Icons.cloud_done_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr(
                              _savingAnonymity
                                  ? 'Saving…'
                                  : _anonymousInCommunity == null
                                  ? 'Loading…'
                                  : _anonymitySaved
                                  ? 'Saved automatically'
                                  : 'This setting saves automatically.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Official links'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: context.tr('Add link'),
                onPressed: _links.length >= 10 ? null : () => _editLink(),
                icon: const Icon(Icons.add_link),
              ),
            ],
          ),
          Text(
            context.tr(
              'Add a website, social network, contact page, or another official link.',
            ),
          ),
          for (final (index, link) in _links.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(link.label),
              subtitle: Text(
                link.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _editLink(index: index),
              trailing: IconButton(
                tooltip: context.tr('Remove'),
                onPressed: () => setState(() => _links.removeAt(index)),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.rule_outlined),
            title: Text(context.tr('Community rules')),
            trailing: const Icon(Icons.chevron_right),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || _uploadingImage ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(context.tr('Save changes')),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateCommunity(
        widget.community,
        name: _name.text.trim(),
        description: _description.text.trim(),
        visibility: _visibility,
        approvalRequired: _approvalRequired,
        showWeather: _showWeather,
        links: List.unmodifiable(_links),
        imageUrl: _imageUrl,
        imageBlobName: _imageBlobName,
      );
      if (mounted) Navigator.pop(context, updated);
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

  Future<void> _editLink({int? index}) async {
    final label = TextEditingController(
      text: index == null ? '' : _links[index].label,
    );
    final url = TextEditingController(
      text: index == null ? '' : _links[index].url,
    );
    final result = await showDialog<CommunityLink>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(
            index == null ? 'Add official link' : 'Edit official link',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              maxLength: CommunityInputLimits.linkLabel,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: InputDecoration(
                labelText: context.tr('Label'),
                hintText: context.tr('Website, Facebook, WhatsApp…'),
              ),
            ),
            TextField(
              controller: url,
              maxLength: CommunityInputLimits.linkUrl,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'HTTPS URL',
                hintText: 'https://',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = Uri.tryParse(url.text.trim());
              if (label.text.characters.length >
                      CommunityInputLimits.linkLabel ||
                  url.text.characters.length > CommunityInputLimits.linkUrl ||
                  label.text.trim().isEmpty ||
                  parsed?.scheme != 'https' ||
                  parsed?.host.isEmpty != false) {
                return;
              }
              Navigator.pop(
                dialogContext,
                CommunityLink(label: label.text.trim(), url: parsed.toString()),
              );
            },
            child: Text(context.tr('Save')),
          ),
        ],
      ),
    );
    label.dispose();
    url.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _links.add(result);
      } else {
        _links[index] = result;
      }
    });
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The community photo must be under 10 MB.'),
          ),
        );
      }
      return;
    }
    setState(() => _uploadingImage = true);
    try {
      final media = await widget.repository.uploadPostMedia(
        bytes: bytes,
        filename: file.name,
        mimeType: file.mimeType ?? _imageMimeType(file.name),
      );
      if (media.type != 'image') {
        throw Exception('Choose a supported image file.');
      }
      if (!mounted) return;
      setState(() {
        _imageUrl = media.url;
        _imageBlobName = media.blobName;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String _imageMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
