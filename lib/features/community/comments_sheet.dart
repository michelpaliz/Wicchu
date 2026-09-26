import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'post_card.dart';
import 'user_avatar.dart';

Future<int?> showPostComments(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post,
) async {
  var latestCount = post.commentCount;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CommentsSheet(
      repository: repository,
      post: post,
      onCountChanged: (count) => latestCount = count,
    ),
  );
  return latestCount;
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.repository,
    required this.post,
    required this.onCountChanged,
  });

  final CommunityRepository repository;
  final CommunityPost post;
  final ValueChanged<int> onCountChanged;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  late final Future<WicchuProfile?> _viewer = widget.repository
      .getProfile()
      .then<WicchuProfile?>((value) => value)
      .catchError((Object _) => null);
  final _savingReactions = <String>{};
  final _expandedThreads = <String>{};
  late Future<List<Comment>> _comments;
  late int _count = widget.post.commentCount;
  bool _saving = false;
  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _comments = _loadComments();
  }

  @override
  void dispose() {
    _inputFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<List<Comment>> _loadComments() async {
    final comments = await widget.repository.listComments(widget.post.id);
    if (mounted) setState(() => _count = comments.length);
    widget.onCountChanged(_count);
    return comments;
  }

  void _retry() => setState(() => _comments = _loadComments());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom) *
            .94,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          context.tr('Comments'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$_count',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: .08),
            ),
            Expanded(
              child: FutureBuilder<List<Comment>>(
                future: _comments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _CommentsError(
                      message: context.trError(snapshot.error!),
                      onRetry: _retry,
                    );
                  }
                  final comments = snapshot.data ?? const [];
                  if (comments.isEmpty) return const _EmptyComments();
                  final ids = comments.map((comment) => comment.id).toSet();
                  String? parentOf(Comment comment) {
                    final target = comment.replyToCommentId;
                    if (target != null &&
                        target != comment.id &&
                        ids.contains(target)) {
                      return target;
                    }
                    return comment.parentCommentId;
                  }

                  final roots = comments
                      .where(
                        (comment) =>
                            parentOf(comment) == null ||
                            !ids.contains(parentOf(comment)),
                      )
                      .toList(growable: false);
                  return ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    itemCount: roots.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final root = roots[index];
                      final replies = <(Comment, int)>[];
                      final visited = <String>{root.id};
                      void collect(String parentId, int depth) {
                        for (final comment in comments.where(
                          (c) => parentOf(c) == parentId,
                        )) {
                          if (visited.add(comment.id)) {
                            replies.add((comment, depth));
                            collect(comment.id, depth + 1);
                          }
                        }
                      }

                      collect(root.id, 1);
                      return Column(
                        children: [
                          _CommentItem(
                            comment: root,
                            canReply: true,
                            savingReaction: _savingReactions.contains(root.id),
                            onReaction: () => _toggleReaction(root),
                            onReply: () => _startReply(root),
                          ),
                          if (replies.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 40),
                                child: TextButton.icon(
                                  key: ValueKey('replies-${root.id}'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: () => setState(() {
                                    if (!_expandedThreads.add(root.id)) {
                                      _expandedThreads.remove(root.id);
                                    }
                                  }),
                                  icon: Icon(
                                    _expandedThreads.contains(root.id)
                                        ? Icons.expand_less
                                        : Icons.subdirectory_arrow_right,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _expandedThreads.contains(root.id)
                                        ? context.trCount(
                                            replies.length,
                                            singular: 'Hide {count} reply',
                                            plural: 'Hide {count} replies',
                                          )
                                        : context.trCount(
                                            replies.length,
                                            singular: 'View {count} reply',
                                            plural: 'View {count} replies',
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          if (_expandedThreads.contains(root.id))
                            Container(
                              margin: const EdgeInsets.only(left: 16),
                              padding: const EdgeInsets.only(left: 14),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: .14),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  for (final (reply, _) in replies)
                                    Padding(
                                      key: ValueKey(
                                        'comment-thread-${reply.id}',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: _CommentItem(
                                        comment: reply,
                                        compact: true,
                                        canReply: true,
                                        savingReaction: _savingReactions
                                            .contains(reply.id),
                                        onReaction: () =>
                                            _toggleReaction(reply),
                                        onReply: () => _startReply(reply),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: .08),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  _replyingTo == null ? 12 : 6,
                  16,
                  12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: .55,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.reply_rounded, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('Replying to {name}', {
                                  'name': _replyingTo!.authorName,
                                }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              onPressed: () =>
                                  setState(() => _replyingTo = null),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 10, bottom: 6),
                          child: FutureBuilder<WicchuProfile?>(
                            future: _viewer,
                            builder: (context, snapshot) => UserAvatar(
                              name: snapshot.data?.name ?? context.tr('You'),
                              imageUrl: snapshot.data?.avatarUrl,
                              radius: 18,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(fontSize: 16),
                            focusNode: _inputFocus,
                            onChanged: (_) => setState(() {}),
                            enabled: !_saving,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 5000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: context.tr(
                                _replyingTo == null
                                    ? 'Write a comment'
                                    : 'Write a reply',
                              ),
                              counterText: '',
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: .12,
                                  ),
                                ),
                              ),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          tooltip: context.tr('Send comment'),
                          onPressed: _saving || _controller.text.trim().isEmpty
                              ? null
                              : _submit,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startReply(Comment comment) {
    setState(() {
      _replyingTo = comment;
      _expandedThreads.add(comment.id);
    });
    _inputFocus.requestFocus();
  }

  Future<bool> _ensureRulesAccepted() async {
    final result = await widget.repository.listRules(widget.post.communityId);
    if (!result.acceptanceRequired) return true;
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Community rules')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: result.rules.length,
            itemBuilder: (context, index) {
              final rule = result.rules[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(rule.title),
                subtitle: Text(rule.description),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Accept rules')),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    await widget.repository.acceptRules(
      widget.post.communityId,
      result.rulesVersion,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Rules accepted'))));
    }
    return true;
  }

  Future<void> _toggleReaction(Comment comment) async {
    setState(() => _savingReactions.add(comment.id));
    try {
      await widget.repository.setCommentReaction(
        comment.id,
        reacted: !comment.reactedByMe,
      );
      if (!mounted) return;
      setState(() {
        _savingReactions.remove(comment.id);
        _comments = _loadComments();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingReactions.remove(comment.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      if (!await _ensureRulesAccepted()) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      await widget.repository.createComment(
        widget.post.id,
        text,
        parentCommentId: _replyingTo?.id,
      );
      _controller.clear();
      _count++;
      widget.onCountChanged(_count);
      if (!mounted) return;
      setState(() {
        _replyingTo = null;
        _comments = _loadComments();
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.savingReaction,
    required this.onReaction,
    this.canReply = false,
    this.compact = false,
    this.onReply,
  });

  final bool compact;
  final Comment comment;
  final bool savingReaction;
  final VoidCallback onReaction;
  final bool canReply;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          name: comment.authorName,
          imageUrl: comment.authorAvatarUrl,
          radius: compact ? 14 : 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPostTime(context, comment.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (comment.replyToName != null) ...[
                  Text(
                    '↳ ${comment.replyToName!}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  comment.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: comment.reactedByMe
                            ? const Color(0xFFE53945)
                            : theme.colorScheme.onSurfaceVariant,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: savingReaction ? null : onReaction,
                      icon: Icon(
                        comment.reactedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 17,
                      ),
                      label: Text(
                        comment.reactionCount == 0
                            ? context.tr('Like')
                            : '${context.tr('Like')} · ${comment.reactionCount}',
                      ),
                    ),
                    if (canReply)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: onReply,
                        child: Text(context.tr('Reply')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('No comments yet'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Be the first to start the conversation.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CommentsError extends StatelessWidget {
  const _CommentsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('Retry')),
          ),
        ],
      ),
    ),
  );
}
