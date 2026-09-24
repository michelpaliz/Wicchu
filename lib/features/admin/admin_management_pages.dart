import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'rule_management_page.dart';

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
            {'category': category.name},
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
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late String _icon = widget.category?.icon ?? '💬';
  bool _saving = false;
  String? _error;

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
          name: _name.text.trim(),
          description: _description.text.trim(),
          icon: _icon,
        );
      } else {
        await widget.repository.updateCategory(
          widget.community.id,
          widget.category!,
          name: _name.text.trim(),
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
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Members'))),
    body: FutureBuilder<List<CommunityMember>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final members = snapshot.data ?? const [];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    child: Text(
                      member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
                    ),
                  ),
                  if (member.isOnline)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(member.name),
              subtitle: Text(
                member.isOnline
                    ? context.tr('Online now')
                    : member.lastActiveAt != null
                    ? context.tr('Active recently')
                    : member.userId,
              ),
              trailing: member.role == CommunityRole.owner
                  ? Chip(label: Text(context.tr('Owner')))
                  : DropdownButton<CommunityRole>(
                      value: member.role,
                      items:
                          const [
                                CommunityRole.admin,
                                CommunityRole.moderator,
                                CommunityRole.member,
                              ]
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(context.tr(role.name)),
                                ),
                              )
                              .toList(),
                      onChanged: (role) =>
                          role == null ? null : _setRole(member, role),
                    ),
            );
          },
        );
      },
    ),
  );

  Future<void> _setRole(CommunityMember member, CommunityRole role) async {
    try {
      await widget.repository.setMemberRole(
        widget.community.id,
        member.userId,
        role,
      );
      setState(
        () => _members = widget.repository.listMembers(widget.community.id),
      );
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
  late final TextEditingController _name = TextEditingController(
    text: widget.community.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.community.description,
  );
  late CommunityVisibility _visibility = widget.community.visibility;
  late bool _approvalRequired = widget.community.approvalRequired;
  late bool _showWeather = widget.community.showWeather;
  late String? _imageUrl = widget.community.imageUrl;
  String? _imageBlobName;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Community settings'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 112,
                  child: _imageUrl == null
                      ? ColoredBox(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.groups_outlined, size: 48),
                        )
                      : Image.network(
                          _imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              Positioned(
                right: -8,
                bottom: -8,
                child: IconButton.filled(
                  tooltip: 'Change community photo',
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
            child: const Text('Remove photo'),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: context.tr('Name')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _description,
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
          subtitle: Text(context.tr('Display current conditions for the community town.')),
          value: _showWeather,
          onChanged: (value) => setState(() => _showWeather = value),
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
  );

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateCommunity(
        widget.community,
        name: _name.text.trim(),
        description: _description.text.trim(),
        visibility: _visibility,
        approvalRequired: _approvalRequired,
        showWeather: _showWeather,
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
