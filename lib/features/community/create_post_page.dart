import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../config/wicchu_urls.dart';
import '../../localization/app_language.dart';
import '../../widgets/responsive_side_panel.dart';
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

Future<CommunityPost?> openPostComposer(
  BuildContext context, {
  required Community community,
  required CommunityRepository repository,
  CommunityCategory? initialCategory,
  List<CommunityCategory> categories = const [],
  CommunityPost? existingPost,
}) {
  final page = CreatePostPage(
    community: community,
    repository: repository,
    initialCategory: initialCategory,
    categories: categories,
    existingPost: existingPost,
  );
  if (MediaQuery.sizeOf(context).width < webDesktopBreakpoint) {
    return Navigator.push<CommunityPost>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
  return showGeneralDialog<CommunityPost>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 560,
          height: double.infinity,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 18,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            child: page,
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
  );
}

class _CreatePostPageState extends State<CreatePostPage> {
  late final Future<WicchuProfile> _postingAuthor = widget.repository
      .getProfile();
  CommunityCategory? _category;
  late final PostTextController _textController;
  bool _saving = false;
  bool _uploading = false;
  final _attachments = <_PostAttachment>[];
  late final Set<String> _mentionedUserIds = {
    ...?widget.existingPost?.mentionedUserIds,
  };
  bool _hasPoll = false;
  late bool _publishAnonymously = widget.existingPost?.isAnonymous ?? false;
  final _pollControllers = [TextEditingController(), TextEditingController()];
  int _step = 0;
  _PostKind _kind = _PostKind.text;
  CommunityPost? _publishedPost;
  bool get _isEditing => widget.existingPost != null;
  bool get _pollLocked => (widget.existingPost?.poll?.totalVotes ?? 0) > 0;
  bool get _canPublishAsAdmin => const {
    CommunityRole.owner,
    CommunityRole.admin,
    CommunityRole.moderator,
  }.contains(widget.community.myRole);
  bool get _canPublishAnonymously => widget.community.myRole != null;

  Future<void> _chooseMentions() async {
    final members = (await widget.repository.listMembers(widget.community.id))
        .where((member) => !member.isAnonymous && member.userId.isNotEmpty)
        .toList(growable: false);
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
                  title: Text(context.tr('Tag')),
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
    _textController.addListener(_refreshValidity);
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
        _kind = _PostKind.poll;
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
      } else if (existingPost.media.isNotEmpty) {
        _kind = _PostKind.media;
      }
    }
  }

  void _refreshValidity() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    if (!widget.community.canPublish ||
        _saving ||
        _uploading ||
        _category == null ||
        _textController.document.toPlainText().trim().isEmpty ||
        _textController.exceedsCharacterLimit) {
      return false;
    }
    if (!_hasPoll) return true;
    final options = _pollControllers
        .map((controller) => controller.text.trim())
        .toList();
    return options.length >= 2 &&
        options.every((option) => option.isNotEmpty) &&
        options.toSet().length == options.length;
  }

  @override
  void dispose() {
    _textController.removeListener(_refreshValidity);
    _textController.dispose();
    for (final controller in _pollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) return _legacyBuild(context);
    if (!widget.community.canPublish) return _permissionDenied(context);
    if (_publishedPost case final post?) return _successScreen(context, post);
    final categories =
        widget.categories.isEmpty && widget.initialCategory != null
        ? [widget.initialCategory!]
        : widget.categories;
    return PopScope(
      canPop: _step == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && !_saving) {
          setState(() => _step--);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: _saving
                ? null
                : _step == 0
                ? () => Navigator.pop(context)
                : () => setState(() => _step--),
          ),
          title: Text(
            context.tr('Create post'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: [
            _stepProgress(context),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: ListView(
                  key: ValueKey(_step),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    switch (_step) {
                      0 => _typeStep(context, categories),
                      1 => _contentStep(context),
                      2 => _optionsStep(context),
                      _ => _previewStep(context),
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _stepNavigation(context),
      ),
    );
  }

  Widget _permissionDenied(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Create post'))),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.tr('You do not have permission to publish in this space.'),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _stepProgress(BuildContext context) {
    final labels = ['Type', 'Content', 'Options', 'Preview'];
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: context.tr('Step {current} of {total}', {
        'current': '${_step + 1}',
        'total': '4',
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index <= _step
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index <= _step
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(labels[index]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: index == _step
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: index == _step
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 12,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: index < _step ? colors.primary : colors.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeStep(BuildContext context, List<CommunityCategory> categories) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('What would you like to share?'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(context.tr('Choose a format. You can adjust it later.')),
          const SizedBox(height: 18),
          _postingDestination(context),
          const SizedBox(height: 16),
          DropdownButtonFormField<CommunityCategory>(
            initialValue: _category,
            isExpanded: true,
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
          _kindCard(
            context,
            kind: _PostKind.text,
            icon: Icons.notes_outlined,
            title: 'Standard post',
            subtitle: 'Share an update, idea, or local news.',
          ),
          _kindCard(
            context,
            kind: _PostKind.media,
            icon: Icons.photo_library_outlined,
            title: 'Photos or video',
            subtitle: 'Tell your story with up to 10 media files.',
          ),
          _kindCard(
            context,
            kind: _PostKind.poll,
            icon: Icons.poll_outlined,
            title: 'Poll',
            subtitle: 'Ask a question and let members vote.',
          ),
        ],
      );

  Widget _kindCard(
    BuildContext context, {
    required _PostKind kind,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _kind == kind;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .55)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('post-kind-${kind.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() {
            _kind = kind;
            _hasPoll = kind == _PostKind.poll;
          }),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(title),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(context.tr(subtitle)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? colors.primary : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contentStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Create your content'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(context.tr('Write your post and add anything it needs.')),
      const SizedBox(height: 18),
      PostRichTextEditor(controller: _textController),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _saving ? null : _chooseMentions,
        icon: const Icon(Icons.alternate_email),
        label: Text(
          _mentionedUserIds.isEmpty
              ? context.tr('Tag members')
              : context.tr('{count} tagged', {
                  'count': '${_mentionedUserIds.length}',
                }),
        ),
      ),
      if (_kind == _PostKind.media || _attachments.isNotEmpty) ...[
        const SizedBox(height: 22),
        _mediaEditor(context),
      ] else ...[
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => setState(() => _kind = _PostKind.media),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(context.tr('Add photos or video')),
        ),
      ],
      if (_hasPoll) ...[const SizedBox(height: 22), _pollEditor(context)],
    ],
  );

  Widget _optionsStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Post options'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(context.tr('Review how this post will be published.')),
      const SizedBox(height: 20),
      _postingDestination(context),
      if (_canPublishAnonymously) ...[
        const SizedBox(height: 16),
        _anonymousOption(context),
      ],
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(context.tr('Category')),
          subtitle: Text(
            _category == null
                ? context.tr('Not selected')
                : '${_category!.icon} ${context.tr(_category!.name)}',
          ),
          trailing: TextButton(
            onPressed: () => setState(() => _step = 0),
            child: Text(context.tr('Change')),
          ),
        ),
      ),
    ],
  );

  Widget _previewStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Preview'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(context.tr('Review everything before publishing.')),
      const SizedBox(height: 18),
      FutureBuilder<WicchuProfile>(
        future: _postingAuthor,
        builder: (context, snapshot) {
          final author = _publishAnonymously
              ? context.tr(
                  _canPublishAsAdmin ? 'Community Admin' : 'Anonymous Member',
                )
              : snapshot.data?.name ?? context.tr('You');
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${widget.community.name} · ${_category == null ? '' : context.tr(_category!.name)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 28),
                  Text(_textController.text.trim()),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 180,
                      child: PostMediaGallery(
                        media: _attachments.map((item) => item.media).toList(),
                      ),
                    ),
                  ],
                  if (_hasPoll) ...[
                    const SizedBox(height: 14),
                    for (final option in _pollControllers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(option.text.trim()),
                        ),
                      ),
                  ],
                  if (_textController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            _copyDescription(_textController.text.trim()),
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(context.tr('Copy description')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _postingDestination(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_2_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${context.tr('Posting to')} '),
                TextSpan(
                  text: widget.community.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _anonymousOption(BuildContext context) => Card(
    child: SwitchListTile.adaptive(
      value: _publishAnonymously,
      onChanged: _saving
          ? null
          : (value) => setState(() => _publishAnonymously = value),
      secondary: const Icon(Icons.person_off_outlined),
      title: Text(context.tr('Publish anonymously')),
      subtitle: Text(
        context.tr(
          _canPublishAsAdmin
              ? '“Community Admin” will appear instead of your name. Your identity remains available for security and auditing.'
              : 'Anonymous posts are always reviewed by a community administrator before publication. Administrators can still identify you for safety.',
        ),
      ),
    ),
  );

  Widget _mediaEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.tr('Media'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text('${_attachments.length}/10'),
        ],
      ),
      const SizedBox(height: 10),
      if (_uploading) const LinearProgressIndicator(),
      SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachments.length + (_attachments.length < 10 ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == _attachments.length) {
              return SizedBox(
                width: 108,
                child: OutlinedButton.icon(
                  onPressed: _saving || _uploading ? null : _chooseMedia,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(context.tr('Add')),
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
                      onPressed: _saving
                          ? null
                          : () => setState(() => _attachments.removeAt(index)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _pollEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Poll options'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      for (final (index, controller) in _pollControllers.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: controller,
            onChanged: (_) => _refreshValidity(),
            enabled: !_pollLocked,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: context.tr('Option {number}', {
                'number': '${index + 1}',
              }),
              counterText: '',
              suffixIcon: !_pollLocked && _pollControllers.length > 2
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
      if (!_pollLocked && _pollControllers.length < 10)
        TextButton.icon(
          onPressed: () =>
              setState(() => _pollControllers.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: Text(context.tr('Add option')),
        ),
    ],
  );

  bool get _canContinue => switch (_step) {
    0 => _category != null,
    1 =>
      _textController.text.trim().isNotEmpty &&
          !_textController.exceedsCharacterLimit &&
          !_uploading &&
          (_kind != _PostKind.media || _attachments.isNotEmpty) &&
          (!_hasPoll ||
              (_pollControllers.length >= 2 &&
                  _pollControllers.every(
                    (controller) => controller.text.trim().isNotEmpty,
                  ) &&
                  _pollControllers
                          .map((item) => item.text.trim())
                          .toSet()
                          .length ==
                      _pollControllers.length)),
    2 => true,
    _ => _canSubmit,
  };

  Widget _stepNavigation(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
    child: Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => setState(() => _step--),
              child: Text(context.tr('Back')),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: _step == 0 ? 1 : 2,
          child: FilledButton.icon(
            key: ValueKey(_step == 3 ? 'publish-post' : 'next-post-step'),
            onPressed: !_canContinue || _saving
                ? null
                : _step == 3
                ? _publish
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => _step++);
                  },
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_step == 3 ? Icons.publish : Icons.arrow_forward),
            label: Text(context.tr(_step == 3 ? 'Publish' : 'Next')),
          ),
        ),
      ],
    ),
  );

  Widget _successScreen(BuildContext context, CommunityPost post) {
    final pending = post.status == PostStatus.pendingApproval;
    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: Text(context.tr(pending ? 'Submitted' : 'Published')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                  pending ? Icons.hourglass_top : Icons.check,
                  size: 54,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  pending ? 'Post submitted for approval' : 'Post published',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  pending
                      ? 'A community moderator will review it before publication.'
                      : 'Your post is live and can now be shared.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, post),
                  child: Text(context.tr('View post')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _resetComposer,
                  child: Text(context.tr('Create another post')),
                ),
              ),
              if (!pending) ...[
                const SizedBox(height: 28),
                Text(
                  context.tr('Share elsewhere'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (post.text.trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _copyDescription(post.text.trim()),
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(context.tr('Copy description')),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => sharePost(
                        context,
                        widget.repository,
                        post,
                        communityName: widget.community.name,
                      ),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text(context.tr('Share post')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: WicchuUrls.post(post.id)),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('Link copied'))),
                          );
                        }
                      },
                      icon: const Icon(Icons.link),
                      label: Text(context.tr('Copy link')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyDescription(String description) async {
    await Clipboard.setData(ClipboardData(text: description));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('Description copied'))));
  }

  void _resetComposer() {
    _textController.clear();
    _attachments.clear();
    _mentionedUserIds.clear();
    _publishAnonymously = false;
    _hasPoll = false;
    _kind = _PostKind.text;
    for (final controller in _pollControllers) {
      controller.dispose();
    }
    _pollControllers
      ..clear()
      ..addAll([TextEditingController(), TextEditingController()]);
    setState(() {
      _publishedPost = null;
      _step = 0;
    });
  }

  Widget _legacyBuild(BuildContext context) {
    if (!widget.community.canPublish) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('Create post'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr(
                'You do not have permission to publish in this space.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final categories =
        widget.categories.isEmpty && widget.initialCategory != null
        ? [widget.initialCategory!]
        : widget.categories;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(_isEditing ? 'Edit post' : 'Create post'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _canSubmit ? _publish : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(72, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .09),
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
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${context.tr('Posting to')} ',
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                          TextSpan(
                            text: widget.community.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.community.isPublicProfile && !_publishAnonymously)
            FutureBuilder<WicchuProfile>(
              future: _postingAuthor,
              builder: (context, snapshot) => snapshot.hasData
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.tr('Posting as {name}', {
                          'name': snapshot.data!.name,
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CommunityCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Category'),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
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
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _saving
                  ? null
                  : () => setState(
                      () => _publishAnonymously = !_publishAnonymously,
                    ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Publish anonymously'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('About anonymous posting'),
                    icon: const Icon(Icons.info_outline, size: 20),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(context.tr('Publish anonymously')),
                        content: Text(
                          context.tr(
                            _canPublishAsAdmin
                                ? '“Community Admin” will appear instead of your name. Your identity remains available for security and auditing.'
                                : 'Anonymous posts are always reviewed by a community administrator before publication. Administrators can still identify you for safety.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(
                              MaterialLocalizations.of(
                                context,
                              ).closeButtonLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _publishAnonymously,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _publishAnonymously = value),
                  ),
                ],
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
                      ? context.tr('Tag')
                      : context.tr('{count} tagged', {
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
                label: Text(context.tr(_hasPoll ? 'Remove poll' : 'Poll')),
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
                        onChanged: (_) => _refreshValidity(),
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
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  _attachments.length + (_attachments.length < 10 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == _attachments.length) {
                  return SizedBox(
                    width: 100,
                    child: CustomPaint(
                      foregroundPainter: _MediaAddBorder(
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .3),
                      ),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide.none,
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
                    ),
                  );
                }
                final attachment = _attachments[index];
                return SizedBox(
                  width: 100,
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
            context.tr('Photos and videos · Max. 10 files'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseMedia() async {
    if (_uploading || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
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
    if (_saving || !widget.community.canPublish) return;
    if (_textController.exceedsCharacterLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Use at most {count} characters.', {
              'count': '${PostTextController.maxCharacters}',
            }),
          ),
        ),
      );
      return;
    }
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
      final currentSpace = await widget.repository.getCommunity(
        widget.community.id,
      );
      if (!currentSpace.canPublish) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'You do not have permission to publish in this space.',
                ),
              ),
            ),
          );
        }
        return;
      }
      final input = CreatePostInput(
        categoryId: _category!.id,
        text: text,
        media: _attachments.map((item) => item.media).toList(),
        pollOptions: pollOptions,
        mentionedUserIds: _mentionedUserIds.toList(growable: false),
        anonymousAsAdmin: _publishAnonymously && _canPublishAsAdmin,
        anonymousAsMember: _publishAnonymously && !_canPublishAsAdmin,
      );
      final post = _isEditing
          ? await widget.repository.updatePost(widget.existingPost!.id, input)
          : await widget.repository.createPost(widget.community.id, input);
      if (!mounted) return;
      if (_isEditing) {
        Navigator.pop(context, post);
      } else {
        setState(() {
          _saving = false;
          _publishedPost = post;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _pickMedia({required bool video}) async {
    if (_uploading || _saving) return;
    if (_attachments.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('A post supports up to 10 files.'))),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      final file = video
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 90,
              requestFullMetadata: false,
            );
      if (file == null || !mounted) return;
      if (await file.length() > 25 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('The file must be under 25 MB.')),
            ),
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final media = await widget.repository.uploadPostMedia(
        bytes: bytes,
        filename: file.name,
        mimeType: file.mimeType ?? _mimeTypeFor(file.name, video: video),
      );
      if (mounted) {
        setState(() => _attachments.add(_PostAttachment(media, bytes)));
      }
    } catch (error) {
      if (mounted) {
        final denied =
            error is PlatformException &&
            {
              'photo_access_denied',
              'photo_access_restricted',
            }.contains(error.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              denied
                  ? context.tr(
                      'Allow photo access for Wicchu in iPhone Settings, then try again.',
                    )
                  : context.trError(error),
            ),
          ),
        );
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
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'gif' => 'image/gif',
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

enum _PostKind { text, media, poll }

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
    return await openPostComposer(
      context,
      community: community,
      repository: repository,
      categories: categories,
      existingPost: post,
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

class _MediaAddBorder extends CustomPainter {
  const _MediaAddBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(12),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 10) {
        canvas.drawPath(metric.extractPath(offset, offset + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MediaAddBorder oldDelegate) => color != oldDelegate.color;
}
