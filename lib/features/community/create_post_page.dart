import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'post_rich_text_editor.dart';
import 'post_share.dart';
import 'post_media_gallery.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.community,
    required this.repository,
    this.initialCategory,
    this.categories = const [],
    this.existingPost,
  });

  final Community community;
  final CommunityRepository repository;
  final CommunityCategory? initialCategory;
  final List<CommunityCategory> categories;
  final CommunityPost? existingPost;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  CommunityCategory? _category;
  late final PostTextController _textController;
  bool _saving = false;
  bool _uploading = false;
  final _attachments = <_PostAttachment>[];
  late final Set<String> _mentionedUserIds = {
    ...?widget.existingPost?.mentionedUserIds,
  };
  bool _hasPoll = false;
  late bool _anonymousAsAdmin = widget.existingPost?.isAnonymous ?? false;
  final _pollControllers = [TextEditingController(), TextEditingController()];
  bool get _isEditing => widget.existingPost != null;
  bool get _pollLocked => (widget.existingPost?.poll?.totalVotes ?? 0) > 0;
  bool get _canPublishAnonymously => const {
    CommunityRole.owner,
    CommunityRole.admin,
    CommunityRole.moderator,
  }.contains(widget.community.myRole);

  Future<void> _chooseMentions() async {
    final members = await widget.repository.listMembers(widget.community.id);
    if (!mounted) return;
    final selected = {..._mentionedUserIds};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                ListTile(
                  title: Text(context.tr('Tag members')),
                  subtitle: Text(
                    context.tr(
                      'Tagged members receive a notification when the post is published.',
                    ),
                  ),
                  trailing: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    child: Text(context.tr('Done')),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return CheckboxListTile(
                        value: selected.contains(member.userId),
                        title: Text(member.name),
                        secondary: CircleAvatar(
                          backgroundImage: member.avatarUrl == null
                              ? null
                              : NetworkImage(member.avatarUrl!),
                          child: member.avatarUrl == null
                              ? Text(member.name.characters.firstOrNull ?? '?')
                              : null,
                        ),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            if (selected.length < 20) {
                              selected.add(member.userId);
                            }
                          } else {
                            selected.remove(member.userId);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final newlySelected = result.difference(_mentionedUserIds);
    for (final userId in newlySelected) {
      final member = members.where((item) => item.userId == userId).firstOrNull;
      if (member != null) {
        _textController.insertMention(member.userId, member.name);
      }
    }
    setState(() {
      _mentionedUserIds
        ..clear()
        ..addAll(result);
    });
  }

  @override
  void initState() {
    super.initState();
    final existingPost = widget.existingPost;
    _textController = PostTextController(existingPost?.text ?? '');
    _category = existingPost == null
        ? widget.initialCategory ?? widget.categories.firstOrNull
        : widget.categories
              .where((category) => category.id == existingPost.categoryId)
              .firstOrNull;
    if (existingPost != null) {
      _attachments.addAll(
        existingPost.media.map((media) => _PostAttachment(media, null)),
      );
      if (existingPost.poll != null) {
        _hasPoll = true;
        for (final controller in _pollControllers) {
          controller.dispose();
        }
        _pollControllers
          ..clear()
          ..addAll(
            existingPost.poll!.options.map(
              (option) => TextEditingController(text: option.text),
            ),
          );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final controller in _pollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.categories.isEmpty && widget.initialCategory != null
        ? [widget.initialCategory!]
        : widget.categories;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_isEditing ? 'Edit post' : 'Create post')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving || _uploading ? null : _publish,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr(_isEditing ? 'Save' : 'Publish')),
            ),
          ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Semantics(
            container: true,
            label: '${context.tr('Posting to')} ${widget.community.name}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_2_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Posting to'),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                        Text(
                          widget.community.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<CommunityCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Category'),
              filled: false,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.15),
                ),
              ),
            ),
            items: [
              for (final item in categories)
                DropdownMenuItem(
                  value: item,
                  child: Text('${item.icon} ${context.tr(item.name)}'),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          if (_canPublishAnonymously) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _anonymousAsAdmin,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _anonymousAsAdmin = value),
              secondary: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(context.tr('Publish as Community Admin')),
              subtitle: Text(
                context.tr(
                  'Members will not see your personal profile. Your identity remains available for security and auditing.',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          PostRichTextEditor(controller: _textController),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _chooseMentions,
                icon: const Icon(Icons.alternate_email),
                label: Text(
                  _mentionedUserIds.isEmpty
                      ? context.tr('Tag members')
                      : context.tr('Tagged members: {count}', {
                          'count': '${_mentionedUserIds.length}',
                        }),
                ),
              ),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _pollLocked
                    ? null
                    : () => setState(() => _hasPoll = !_hasPoll),
                icon: Icon(_hasPoll ? Icons.close : Icons.poll_outlined),
                label: Text(context.tr(_hasPoll ? 'Remove poll' : 'Add poll')),
              ),
            ],
          ),
          if (_hasPoll) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.how_to_vote_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('Poll'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_pollControllers.length}/10',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      _pollLocked
                          ? 'Poll options cannot be changed after voting begins.'
                          : 'Ask your community a question and let members vote.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final (index, controller) in _pollControllers.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controller,
                        enabled: !_pollLocked,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: context.tr('Option {number}', {
                            'number': '${index + 1}',
                          }),
                          counterText: '',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircleAvatar(
                              radius: 14,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          suffixIcon:
                              !_pollLocked && _pollControllers.length > 2
                              ? IconButton(
                                  tooltip: context.tr('Remove option'),
                                  onPressed: () => setState(() {
                                    _pollControllers.removeAt(index).dispose();
                                  }),
                                  icon: const Icon(Icons.close),
                                )
                              : null,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('At least 2 options'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      if (!_pollLocked && _pollControllers.length < 10)
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _pollControllers.add(TextEditingController()),
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(context.tr('Add option')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Media'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_attachments.length}/10',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_uploading) const LinearProgressIndicator(),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  _attachments.length + (_attachments.length < 10 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == _attachments.length) {
                  return SizedBox(
                    width: 108,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      onPressed: _saving || _uploading ? null : _chooseMedia,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 30),
                          const SizedBox(height: 8),
                          Text(context.tr('Add')),
                        ],
                      ),
                    ),
                  );
                }
                final attachment = _attachments[index];
                return SizedBox(
                  width: 108,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            attachment.bytes != null &&
                                attachment.media.type == 'image'
                            ? Image.memory(attachment.bytes!, fit: BoxFit.cover)
                            : PostMediaGallery(media: [attachment.media]),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton.filled(
                          tooltip: context.tr('Remove'),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: _saving
                              ? null
                              : () => setState(
                                  () => _attachments.removeAt(index),
                                ),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('A post supports up to 10 files.'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseMedia() async {
    final video = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(context.tr('Photo')),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(context.tr('Video')),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (video != null && mounted) await _pickMedia(video: video);
  }

  Future<void> _publish() async {
    final text = _textController.text.trim();
    final pollOptions = _hasPoll
        ? _pollControllers.map((controller) => controller.text.trim()).toList()
        : const <String>[];
    if (_category == null || text.isEmpty || _uploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Choose a category and add text.'))),
      );
      return;
    }
    if (_hasPoll &&
        (pollOptions.any((option) => option.isEmpty) ||
            pollOptions.toSet().length != pollOptions.length)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Add at least two unique poll options.')),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final input = CreatePostInput(
        categoryId: _category!.id,
        text: text,
        media: _attachments.map((item) => item.media).toList(),
        pollOptions: pollOptions,
        mentionedUserIds: _mentionedUserIds.toList(growable: false),
        anonymousAsAdmin: _anonymousAsAdmin,
      );
      final post = _isEditing
          ? await widget.repository.updatePost(widget.existingPost!.id, input)
          : await widget.repository.createPost(widget.community.id, input);
      if (!mounted) return;
      if (post.status == PostStatus.pendingApproval) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.hourglass_top),
            title: Text(dialogContext.tr('Post submitted for approval')),
            content: Text(
              dialogContext.tr(
                'A community moderator will review it before publication.',
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.tr('Done')),
              ),
            ],
          ),
        );
      } else if (!_isEditing) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline, size: 44),
            title: Text(dialogContext.tr('Post published')),
            content: Text(
              dialogContext.tr(
                'Your post is live. Share it with your community elsewhere?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.tr('Not now')),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await sharePost(
                    widget.repository,
                    post,
                    communityName: widget.community.name,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(dialogContext.tr('Share post')),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, post);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _pickMedia({required bool video}) async {
    if (_attachments.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('A post supports up to 10 files.'))),
      );
      return;
    }
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 25 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('The file must be under 25 MB.'))),
        );
      }
      return;
    }
    final mimeType = file.mimeType ?? _mimeTypeFor(file.name, video: video);
    setState(() => _uploading = true);
    try {
      final media = await widget.repository.uploadPostMedia(
        bytes: bytes,
        filename: file.name,
        mimeType: mimeType,
      );
      if (mounted) {
        setState(() => _attachments.add(_PostAttachment(media, bytes)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeTypeFor(String filename, {required bool video}) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mov' => 'video/quicktime',
      'mp4' => 'video/mp4',
      _ => video ? 'video/mp4' : 'image/jpeg',
    };
  }
}

class _PostAttachment {
  const _PostAttachment(this.media, this.bytes);

  final PostMedia media;
  final Uint8List? bytes;
}

Future<CommunityPost?> openEditPost(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post,
) async {
  try {
    final communities = await repository.listJoinedCommunities();
    final community = communities
        .where((item) => item.id == post.communityId)
        .firstOrNull;
    if (community == null) throw StateError('Community not found');
    final categories = await repository.listCategories(community.id);
    if (!context.mounted) return null;
    return await Navigator.push<CommunityPost>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          community: community,
          repository: repository,
          categories: categories,
          existingPost: post,
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
    return null;
  }
}
