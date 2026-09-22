import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'post_format_toolbar.dart';
import 'post_markdown.dart';
import 'post_share.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.community,
    required this.repository,
    this.initialCategory,
    this.categories = const [],
  });

  final Community community;
  final CommunityRepository repository;
  final CommunityCategory? initialCategory;
  final List<CommunityCategory> categories;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  CommunityCategory? _category;
  final _textController = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  final _attachments = <_PostAttachment>[];
  bool _hasPoll = false;
  final _pollControllers = [TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? widget.categories.firstOrNull;
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
      appBar: AppBar(title: Text(context.tr('Create post'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.community.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<CommunityCategory>(
            initialValue: _category,
            decoration: InputDecoration(labelText: context.tr('Category')),
            items: [
              for (final item in categories)
                DropdownMenuItem(
                  value: item,
                  child: Text('${item.icon} ${context.tr(item.name)}'),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 20),
          PostFormatToolbar(controller: _textController),
          TextField(
            controller: _textController,
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: context.tr('What would you like to share?'),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Preview'),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PostMarkdown(data: value.text),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _hasPoll = !_hasPoll),
              icon: const Icon(Icons.poll_outlined),
              label: Text(context.tr(_hasPoll ? 'Remove poll' : 'Add poll')),
            ),
          ),
          if (_hasPoll) ...[
            for (final (index, controller) in _pollControllers.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: controller,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: context.tr('Option {number}', {
                      'number': '${index + 1}',
                    }),
                    suffixIcon: _pollControllers.length > 2
                        ? IconButton(
                            onPressed: () => setState(() {
                              _pollControllers.removeAt(index).dispose();
                            }),
                            icon: const Icon(Icons.close),
                          )
                        : null,
                  ),
                ),
              ),
            if (_pollControllers.length < 10)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(
                    () => _pollControllers.add(TextEditingController()),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Add option')),
                ),
              ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              TextButton.icon(
                onPressed: _uploading ? null : () => _pickMedia(video: false),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(context.tr('Photo')),
              ),
              TextButton.icon(
                onPressed: _uploading ? null : () => _pickMedia(video: true),
                icon: const Icon(Icons.videocam_outlined),
                label: Text(context.tr('Video')),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _publish,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Publish')),
              ),
            ],
          ),
          if (_uploading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final attachment = _attachments[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: attachment.media.type == 'image'
                            ? Image.memory(
                                attachment.bytes,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 92,
                                height: 92,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  size: 38,
                                ),
                              ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton.filled(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _attachments.removeAt(index)),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
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
      final post = await widget.repository.createPost(
        widget.community.id,
        CreatePostInput(
          categoryId: _category!.id,
          text: text,
          media: _attachments.map((item) => item.media).toList(),
          pollOptions: pollOptions,
        ),
      );
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
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline, size: 44),
            title: const Text('Post published ✓'),
            content: const Text(
              'Share with your community elsewhere?\n\n'
              'Facebook · WhatsApp · Messenger · More',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Not now'),
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
                label: const Text('Share post'),
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
  final Uint8List bytes;
}
