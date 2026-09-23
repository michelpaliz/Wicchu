import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

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
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final category = items[index];
            return ListTile(
              leading: Text(
                category.icon,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(category.name),
              subtitle: category.description.isEmpty
                  ? null
                  : Text(category.description),
              onTap: () => _edit(category),
              trailing: IconButton(
                tooltip: context.tr('Delete'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(category),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _edit([CommunityCategory? category]) async {
    final name = TextEditingController(text: category?.name);
    final description = TextEditingController(text: category?.description);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(category == null ? 'Add category' : 'Edit category'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: context.tr('Name')),
            ),
            TextField(
              controller: description,
              decoration: InputDecoration(labelText: context.tr('Description')),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Save')),
          ),
        ],
      ),
    );
    if (save == true && name.text.trim().isNotEmpty) {
      try {
        if (category == null) {
          await widget.repository.createCategory(
            widget.community.id,
            name: name.text.trim(),
            description: description.text.trim(),
          );
        } else {
          await widget.repository.updateCategory(
            widget.community.id,
            category,
            name: name.text.trim(),
            description: description.text.trim(),
          );
        }
        _reload();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.trError(error))));
        }
      }
    }
    name.dispose();
    description.dispose();
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
    await widget.repository.deleteCategory(widget.community.id, category.id);
    _reload();
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
  late String? _imageUrl = widget.community.imageUrl;
  String? _imageBlobName;
  bool _saving = false;
  bool _uploadingImage = false;
  late final List<CommunityRule> _rules = [...widget.community.rules];
  bool _rulesChanged = false;

  Future<void> _editRule([int? index]) async {
    final rule = index == null ? null : _rules[index];
    final updated = await showDialog<CommunityRule>(
      context: context,
      builder: (_) => _RuleEditor(rule: rule),
    );
    if (updated == null || !mounted) return;
    setState(() {
      if (index == null) {
        _rules.add(updated);
      } else {
        _rules[index] = updated;
      }
      _rulesChanged = true;
    });
  }

  void _moveRule(int index, int offset) {
    setState(() {
      final rule = _rules.removeAt(index);
      _rules.insert(index + offset, rule);
      _rulesChanged = true;
    });
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
        const SizedBox(height: 24),
        Text(
          context.tr('Community rules'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Help members understand what belongs in this community.'),
        ),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(context.tr('No community rules have been added yet.')),
          ),
        for (final (index, rule) in _rules.indexed)
          Card(
            child: ListTile(
              leading: CircleAvatar(radius: 16, child: Text('${index + 1}')),
              title: Text(rule.title),
              subtitle: rule.description.isEmpty
                  ? null
                  : Text(rule.description),
              onTap: _saving ? null : () => _editRule(index),
              trailing: PopupMenuButton<String>(
                enabled: !_saving,
                tooltip: context.tr('Rule actions'),
                onSelected: (action) {
                  if (action == 'edit') _editRule(index);
                  if (action == 'up') _moveRule(index, -1);
                  if (action == 'down') _moveRule(index, 1);
                  if (action == 'delete') {
                    setState(() {
                      _rules.removeAt(index);
                      _rulesChanged = true;
                    });
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(context.tr('Edit rule')),
                  ),
                  if (index > 0)
                    PopupMenuItem(
                      value: 'up',
                      child: Text(context.tr('Move up')),
                    ),
                  if (index < _rules.length - 1)
                    PopupMenuItem(
                      value: 'down',
                      child: Text(context.tr('Move down')),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.tr('Delete')),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _saving ? null : () => _editRule(),
            icon: const Icon(Icons.add),
            label: Text(context.tr('Add rule')),
          ),
        ),
        Text(context.tr('Rule changes are applied when you save.')),
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
        imageUrl: _imageUrl,
        imageBlobName: _imageBlobName,
        rules: _rulesChanged ? List.of(_rules) : null,
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

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({this.rule});
  final CommunityRule? rule;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.rule?.title);
  late final _description = TextEditingController(
    text: widget.rule?.description,
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr(widget.rule == null ? 'Add rule' : 'Edit rule')),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.tr('Rule title')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Enter a rule title')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.tr('Description (optional)'),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              CommunityRule(
                title: _title.text.trim(),
                description: _description.text.trim(),
              ),
            );
          }
        },
        child: Text(context.tr('Save')),
      ),
    ],
  );
}
