import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/community_models.dart';
import '../../theme/wicchu_theme.dart';
import '../../localization/app_language.dart';
import 'post_media_gallery.dart';
import 'post_markdown.dart';
import 'user_avatar.dart';

String formatPostTime(BuildContext context, DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt.toLocal());
  if (difference.inMinutes < 1) return context.tr('Now');
  if (difference.inHours < 1) {
    return context.tr('{count} min ago', {'count': '${difference.inMinutes}'});
  }
  if (difference.inDays < 1) {
    return context.tr('{count} h ago', {'count': '${difference.inHours}'});
  }
  if (difference.inDays == 1) return context.tr('Yesterday');
  if (difference.inDays < 7) {
    return context.tr('{count} days ago', {'count': '${difference.inDays}'});
  }
  return MaterialLocalizations.of(context).formatShortDate(createdAt.toLocal());
}

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.category,
    required this.icon,
    required this.community,
    required this.author,
    this.authorAvatarUrl,
    required this.time,
    required this.text,
    this.price,
    this.collapseText = false,
    this.showCommunity = true,
    this.likes = 0,
    this.comments = 0,
    this.showImage = false,
    this.onTap,
    this.reacted = false,
    this.onReaction,
    this.onComments,
    this.saved = false,
    this.onSaved,
    this.media = const [],
    this.onReport,
    this.onShare,
    this.promotion,
    this.onPromotionImpression,
    this.onPromotionClick,
    this.poll,
    this.onPollVote,
    this.onAuthorTap,
    this.edited = false,
    this.onEdit,
    this.onDelete,
    this.onMentionTap,
  });

  final String category;
  final String icon;
  final String community;
  final String author;
  final String? authorAvatarUrl;
  final String time;
  final String text;
  final String? price;
  final bool collapseText;
  final bool showCommunity;
  final int likes;
  final int comments;
  final bool showImage;
  final VoidCallback? onTap;
  final bool reacted;
  final Future<int> Function(bool reacted)? onReaction;
  final Future<int?> Function()? onComments;
  final bool saved;
  final Future<void> Function(bool saved)? onSaved;
  final List<PostMedia> media;
  final Future<void> Function(String reason)? onReport;
  final Future<void> Function()? onShare;
  final PostPromotion? promotion;
  final Future<void> Function()? onPromotionImpression;
  final Future<void> Function()? onPromotionClick;
  final PostPoll? poll;
  final Future<PostPoll> Function(String optionId)? onPollVote;
  final VoidCallback? onAuthorTap;
  final bool edited;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;
  final ValueChanged<String>? onMentionTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _likes = widget.likes;
  late int _comments = widget.comments;
  late bool _reacted = widget.reacted;
  late bool _saved = widget.saved;
  bool _savingReaction = false;
  bool _savingPost = false;
  bool _impressionSent = false;
  late PostPoll? _poll = widget.poll;
  bool _savingVote = false;
  bool _deleting = false;

  Future<void> _deletePost() async {
    if (widget.onDelete == null || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(dialogContext.tr('Delete publication?')),
        content: Text(
          dialogContext.tr(
            'This publication will disappear from Wicchu. This action cannot be undone.',
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
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.onDelete!();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _recordImpression();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.likes != widget.likes) _likes = widget.likes;
    if (oldWidget.comments != widget.comments) _comments = widget.comments;
    if (oldWidget.reacted != widget.reacted) _reacted = widget.reacted;
    if (oldWidget.saved != widget.saved) _saved = widget.saved;
    if (oldWidget.promotion?.id != widget.promotion?.id) {
      _impressionSent = false;
      _recordImpression();
    }
    if (oldWidget.poll != widget.poll) _poll = widget.poll;
  }

  void _recordImpression() {
    if (_impressionSent || widget.onPromotionImpression == null) return;
    _impressionSent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.onPromotionImpression!());
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = categoryColor(widget.category, context);
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.onPromotionClick != null) {
                  unawaited(widget.onPromotionClick!());
                }
                widget.onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.promotion != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr('Sponsored'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: widget.onAuthorTap,
                    customBorder: const CircleBorder(),
                    child: UserAvatar(
                      name: context.tr(widget.author),
                      imageUrl: widget.authorAvatarUrl,
                      radius: 21,
                      backgroundColor: accent.withValues(alpha: .14),
                      foregroundColor: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: widget.onAuthorTap,
                          child: Text(
                            context.tr(widget.author),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.time}${widget.edited ? ' · ${context.tr('Edited')}' : ''}${widget.showCommunity ? ' · ${widget.community}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onSaved != null ||
                      widget.onReport != null ||
                      widget.onEdit != null ||
                      widget.onDelete != null)
                    _PostMenu(
                      saved: _saved,
                      saving: _savingPost || _deleting,
                      onSave: widget.onSaved == null ? null : _toggleSaved,
                      onReport: widget.onReport == null ? null : _report,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete == null ? null : _deletePost,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${widget.icon} ${context.tr(widget.category)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PostMarkdown(
                data: widget.text,
                collapsible: widget.collapseText,
                onUserTap: widget.onMentionTap,
              ),
              if (widget.price != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.price!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              if (widget.media.isNotEmpty) ...[
                const SizedBox(height: 8),
                PostMediaGallery(media: widget.media),
              ] else if (widget.showImage) ...[
                const SizedBox(height: 8),
                Container(
                  height: 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Icon(Icons.image_outlined, size: 54, color: accent),
                ),
              ],
              if (_poll != null) ...[
                const SizedBox(height: 8),
                _PollView(
                  poll: _poll!,
                  enabled: widget.onPollVote != null && !_savingVote,
                  onSelected: _vote,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  _PostAction(
                    icon: _reacted
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    value: '$_likes',
                    tooltip: context.tr(_reacted ? 'Unlike' : 'Like'),
                    color: _reacted ? const Color(0xFFE53945) : null,
                    onTap: widget.onReaction == null || _savingReaction
                        ? null
                        : _toggleReaction,
                  ),
                  const SizedBox(width: 12),
                  _PostAction(
                    icon: CupertinoIcons.chat_bubble,
                    value: '$_comments',
                    tooltip: context.tr('Comments'),
                    onTap: widget.onComments == null ? null : _openComments,
                  ),
                  const Spacer(),
                  Flexible(
                    child: _PostAction(
                      icon: CupertinoIcons.arrowshape_turn_up_right,
                      value: context.tr('Share'),
                      tooltip: context.tr('Share'),
                      onTap: widget.onShare,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _vote(String optionId) async {
    if (widget.onPollVote == null) return;
    setState(() => _savingVote = true);
    try {
      final poll = await widget.onPollVote!(optionId);
      if (mounted) setState(() => _poll = poll);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingVote = false);
    }
  }

  Future<void> _toggleReaction() async {
    final next = !_reacted;
    setState(() => _savingReaction = true);
    try {
      final count = await widget.onReaction!(next);
      if (mounted) {
        setState(() {
          _reacted = next;
          _likes = count;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingReaction = false);
    }
  }

  Future<void> _openComments() async {
    final count = await widget.onComments!();
    if (mounted && count != null) setState(() => _comments = count);
  }

  Future<void> _toggleSaved() async {
    final next = !_saved;
    setState(() => _savingPost = true);
    try {
      await widget.onSaved!(next);
      if (mounted) setState(() => _saved = next);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingPost = false);
    }
  }

  Future<void> _report() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Report post')),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          decoration: InputDecoration(hintText: dialogContext.tr('Reason')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(dialogContext.tr('Report')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await widget.onReport!(reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Report submitted'))));
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

class _PollView extends StatelessWidget {
  const _PollView({
    required this.poll,
    required this.enabled,
    required this.onSelected,
  });
  final PostPoll poll;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final total = poll.totalVotes;
    return RadioGroup<String>(
      groupValue: poll.selectedOptionId,
      onChanged: (value) {
        if (enabled && value != null) onSelected(value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final option in poll.options) ...[
            InkWell(
              onTap: enabled ? () => onSelected(option.id) : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Radio<String>(value: option.id, enabled: enabled),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(option.text)),
                              Text(
                                total == 0
                                    ? '0%'
                                    : '${(option.voteCount * 100 / total).round()}%',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : option.voteCount / total,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Text(
            context.tr('{count} votes', {'count': '$total'}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.value,
    required this.tooltip,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String value;
  final String tooltip;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: '$tooltip, $value',
    excludeSemantics: true,
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({
    required this.saved,
    required this.saving,
    this.onSave,
    this.onReport,
    this.onEdit,
    this.onDelete,
  });

  final bool saved;
  final bool saving;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_PostMenuAction>(
    tooltip: context.tr('More options'),
    enabled: !saving,
    onSelected: (action) {
      switch (action) {
        case _PostMenuAction.save:
          onSave?.call();
        case _PostMenuAction.report:
          onReport?.call();
        case _PostMenuAction.edit:
          onEdit?.call();
        case _PostMenuAction.delete:
          onDelete?.call();
      }
    },
    itemBuilder: (context) => [
      if (onSave != null)
        PopupMenuItem(
          value: _PostMenuAction.save,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            title: Text(context.tr(saved ? 'Unsave post' : 'Save post')),
          ),
        ),
      if (onEdit != null)
        PopupMenuItem(
          value: _PostMenuAction.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: Text(context.tr('Edit post')),
          ),
        ),
      if (onDelete != null)
        PopupMenuItem(
          value: _PostMenuAction.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              context.tr('Delete publication'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      if (onReport != null)
        PopupMenuItem(
          value: _PostMenuAction.report,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(context.tr('Report post')),
          ),
        ),
    ],
    icon: saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.more_horiz),
  );
}

enum _PostMenuAction { save, edit, delete, report }
