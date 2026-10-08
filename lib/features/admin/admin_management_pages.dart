import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/community_models.dart';
import '../../domain/community_input_limits.dart';
import 'package:flutter/services.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'rule_management_page.dart';
import 'official_links_page.dart';
import 'business_services_page.dart';
import 'restaurant_settings_page.dart';
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
                if (widget.community.isPublicProfile &&
                    widget.community.myRole == CommunityRole.owner &&
                    member.status == MembershipStatus.active &&
                    member.role == CommunityRole.admin)
                  ListTile(
                    leading: Icon(
                      member.pageInboxAccess
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                    title: Text(
                      context.tr(
                        member.pageInboxAccess
                            ? 'Remove page inbox access'
                            : 'Allow page inbox access',
                      ),
                    ),
                    subtitle: Text(
                      context.tr('Reply to customers as this page.'),
                    ),
                    onTap: () => Navigator.pop(sheetContext, 'page-inbox'),
                  ),
                if (widget.community.myRole == CommunityRole.owner &&
                    member.status == MembershipStatus.active &&
                    member.role == CommunityRole.admin)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: Text(context.tr('Transfer ownership')),
                    onTap: () => Navigator.pop(sheetContext, 'transfer'),
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
    } else if (action == 'transfer') {
      await _transferOwnership(member);
    } else if (action == 'page-inbox') {
      await _setPageInboxAccess(member);
    } else {
      await _changeAccess(member, action);
    }
  }

  Future<void> _setPageInboxAccess(CommunityMember member) async {
    try {
      await widget.repository.setPageInboxAccess(
        widget.community.id,
        member.userId,
        enabled: !member.pageInboxAccess,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              member.pageInboxAccess
                  ? 'Page inbox access removed.'
                  : 'Page inbox access granted.',
            ),
          ),
        ),
      );
      _reload();
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
            '{name} must accept the transfer. After acceptance, they will become the owner and you will become an administrator.',
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(widget.community.isPublicProfile ? 'Followers' : 'Members'),
      ),
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
                      if (member.status == MembershipStatus.banned)
                        TextButton.icon(
                          key: ValueKey('unban-member-${member.userId}'),
                          onPressed: () => _changeAccess(member, 'unban'),
                          icon: const Icon(Icons.lock_open, size: 18),
                          label: Text(context.tr('Unban')),
                        ),
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
            title: Text(dialogContext.tr('Ban member')),
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
                        'The member will receive this reason.',
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
                child: Text(dialogContext.tr('Ban member')),
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
  late Town _town = widget.community.town;
  late Future<List<Town>> _towns;
  bool _locatingTown = false;
  late ProfileCategory? _profileCategory = widget.community.profileCategory;
  late final Set<BusinessService> _businessServices = {
    ...widget.community.businessServices,
  };
  late bool _approvalRequired = widget.community.approvalRequired;
  late bool _showWeather = widget.community.showWeather;
  bool _showLocationHelp = false;
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
  bool _locatingBusiness = false;
  late final List<CommunityLink> _links = [...widget.community.links];
  late String? _imageUrl = widget.community.imageUrl;
  String? _imageBlobName;
  late String? _coverImageUrl = widget.community.coverImageUrl;
  String? _coverImageBlobName;
  bool _editingName = false;
  bool _saving = false;
  bool _uploadingImage = false;
  bool? _anonymousInCommunity;
  bool _savingAnonymity = false;
  bool _anonymitySaved = false;
  bool _anonymityLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _towns = widget.repository.listTowns();
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

  Widget _settingsSection(String title, IconData icon, List<Widget> children) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(title),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: .08),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(
          widget.community.isPublicProfile
              ? (_profileCategory == ProfileCategory.localBusiness
                    ? 'Business settings'
                    : 'Profile settings')
              : 'Community settings',
        ),
      ),
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
                    Image.network(
                      _coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.landscape_outlined, size: 32),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('edit-community-cover'),
                      onPressed: _uploadingImage || _saving
                          ? null
                          : () => _pickImage(cover: true),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(context.tr('Change cover photo')),
                    ),
                  ),
                  if (_coverImageUrl != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        tooltip: context.tr('Remove cover photo'),
                        onPressed: _uploadingImage || _saving
                            ? null
                            : () => setState(() {
                                _coverImageUrl = null;
                                _coverImageBlobName = '';
                              }),
                        icon: const Icon(Icons.close, size: 18),
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
                      ClipOval(
                        child: SizedBox.square(
                          dimension: 64,
                          child: _imageUrl == null
                              ? ColoredBox(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  child: Icon(
                                    !widget.community.isPublicProfile
                                        ? Icons.groups_outlined
                                        : _profileCategory ==
                                              ProfileCategory.localBusiness
                                        ? Icons.storefront_outlined
                                        : _profileCategory ==
                                              ProfileCategory.organization
                                        ? Icons.apartment_outlined
                                        : Icons.person_outline,
                                    size: 30,
                                  ),
                                )
                              : Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
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
                          onPressed: _uploadingImage
                              ? null
                              : () => _pickImage(cover: false),
                          icon: _uploadingImage
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_camera_outlined),
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
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _name,
                      builder: (context, value, _) => Text(
                        value.text,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      context.tr(widget.community.spaceTypeLabel),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(
                                  () => _editingName = !_editingName,
                                ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(context.tr('Edit')),
                        ),
                        if (_imageUrl != null)
                          TextButton(
                            onPressed: _uploadingImage || _saving
                                ? null
                                : () => setState(() {
                                    _imageUrl = null;
                                    _imageBlobName = '';
                                  }),
                            child: Text(context.tr('Remove photo')),
                          ),
                      ],
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
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.tr('Short description'),
              helperText: context.tr('Shown near the top of the profile.'),
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
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: context.tr('About'),
              helperText: context.tr('The full description shown in About.'),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.community.isPublicProfile) ...[
            DropdownButtonFormField<ProfileCategory>(
              initialValue: _profileCategory,
              decoration: InputDecoration(
                labelText: context.tr('Profile category'),
                prefixIcon: Icon(
                  _profileCategory == ProfileCategory.localBusiness
                      ? Icons.storefront_outlined
                      : Icons.person_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: [
                for (final category in ProfileCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(context.tr(category.label)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _profileCategory = value),
            ),
            const SizedBox(height: 16),
            if (_profileCategory == ProfileCategory.localBusiness)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.home_repair_service_outlined),
                  title: Text(context.tr('Main services')),
                  subtitle: Text(
                    _businessServices.isEmpty
                        ? context.tr(
                            'Choose up to 10 services that describe your business.',
                          )
                        : _businessServices
                              .map((service) => context.tr(service.label))
                              .join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _saving ? null : _openBusinessServices,
                ),
              ),
            if (_profileCategory == ProfileCategory.localBusiness &&
                _businessServices.contains(BusinessService.food)) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(context.tr('Restaurant settings')),
                  subtitle: Text(
                    context.tr('Opening hours, contact and delivery options'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _saving ? null : _openRestaurantSettings,
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          _settingsSection('General', Icons.settings_outlined, [
            Row(
              children: [
                Icon(
                  _visibility == CommunityVisibility.public
                      ? Icons.public
                      : Icons.lock_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr('Visibility'))),
                DropdownButtonHideUnderline(
                  child: DropdownButton<CommunityVisibility>(
                    value: _visibility,
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.keyboard_arrow_down),
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
          ]),
          const SizedBox(height: 12),
          _settingsSection('Location', Icons.location_on_outlined, [
            Text(
              context.tr(
                widget.community.isPublicProfile
                    ? 'Business location'
                    : 'Community location',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FutureBuilder<List<Town>>(
                    future: _towns,
                    builder: (context, snapshot) {
                      final towns = <Town>[
                        _town,
                        for (final town in snapshot.data ?? const <Town>[])
                          if (town.id != _town.id) town,
                      ];
                      return DropdownButtonFormField<Town>(
                        key: ValueKey(_town.id),
                        initialValue: _town,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.tr('Town'),
                          isDense: true,
                          prefixIcon: const Icon(
                            Icons.location_city_outlined,
                            size: 20,
                          ),
                        ),
                        items: [
                          for (final town in towns)
                            DropdownMenuItem(
                              value: town,
                              child: Text(
                                '${town.name} · ${town.countryCode}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _town = value);
                                }
                              },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: context.tr('Use my current town'),
                  onPressed: _locatingTown || _saving ? null : _useCurrentTown,
                  color: Theme.of(context).colorScheme.primary,
                  icon: _locatingTown
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 22),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Text(
                context.tr(
                  widget.community.isPublicProfile
                      ? 'Helps nearby people find your profile.'
                      : 'This location is used for discovery and local weather.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ]),
          if (!widget.community.isPublicProfile ||
              _profileCategory != ProfileCategory.localBusiness) ...[
            _settingsSection('Posts and content', Icons.article_outlined, [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Require post approval')),
                value: _approvalRequired,
                onChanged: (value) => setState(() => _approvalRequired = value),
              ),
            ]),
            _settingsSection('Additional information', Icons.info_outline, [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.cloud_outlined),
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
          if (widget.community.isPublicProfile) ...[
            TextFormField(
              controller: _businessAddress,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: context.tr('Business address'),
                isDense: true,
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: context.tr('Use my current location'),
                  onPressed: _locatingBusiness || _saving
                      ? null
                      : _useCurrentBusinessLocation,
                  color: Theme.of(context).colorScheme.primary,
                  icon: _locatingBusiness
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 22),
                ),
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                hintText: context.tr('Street, town, province'),
              ),
            ),
            if (_businessLatitude != null && _businessLongitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.tr('Map pin saved'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            _compactPrivacySetting(
              title: 'Public exact location',
              description: 'When disabled, visitors only see the profile town.',
              value: _showExactBusinessAddress,
              onChanged: (value) =>
                  setState(() => _showExactBusinessAddress = value),
              expanded: _showLocationHelp,
              onHelp: () =>
                  setState(() => _showLocationHelp = !_showLocationHelp),
            ),
          ],
          const SizedBox(height: 8),
          _settingsSection('Privacy', Icons.privacy_tip_outlined, [
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
                      icon: const Icon(Icons.refresh, size: 18),
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
                            ? Icons.check_circle_outline
                            : Icons.cloud_done_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            ),
          ]),
          const SizedBox(height: 16),
          _settingsSection('Content', Icons.link, [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(context.tr('Official links')),
              subtitle: Text(
                context.tr(
                  'Add a website, social network, contact page, or another official link.',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : _openOfficialLinks,
            ),
            const Divider(height: 16),
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
          ]),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
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
              icon: Icon(expanded ? Icons.info : Icons.info_outline, size: 20),
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
    if (_saving || !_form.currentState!.validate()) return;
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
        businessHours: _businessServices.contains(BusinessService.food)
            ? List.unmodifiable(_businessHours)
            : null,
        businessFulfillmentOptions:
            _businessServices.contains(BusinessService.food)
            ? List.unmodifiable(_businessFulfillmentOptions)
            : null,
        businessContact: _businessServices.contains(BusinessService.food)
            ? _businessContact
            : null,
        imageUrl: _imageUrl,
        imageBlobName: _imageBlobName,
        coverImageUrl: _coverImageUrl,
        coverImageBlobName: _coverImageBlobName,
      );
      if (!mounted) return;
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
      Navigator.pop(context, updated);
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

  Future<void> _useCurrentTown() async {
    setState(() => _locatingTown = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on location services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition();
      final town = await widget.repository.locateTown(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _town = town;
        _towns = widget.repository.listTowns();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _locatingTown = false);
    }
  }

  Future<void> _useCurrentBusinessLocation() async {
    setState(() => _locatingBusiness = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _businessLatitude = position.latitude;
          _businessLongitude = position.longitude;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _locatingBusiness = false);
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

  Future<void> _openBusinessServices() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessServicesPage(
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
      imageQuality: 88,
      maxWidth: cover ? 2400 : 1600,
      maxHeight: cover ? 1200 : 1600,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('The photo must be under 10 MB.'))),
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
        if (cover) {
          _coverImageUrl = media.url;
          _coverImageBlobName = media.blobName;
        } else {
          _imageUrl = media.url;
          _imageBlobName = media.blobName;
        }
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
