import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/community_models.dart';
import '../../theme/wicchu_theme.dart';
import '../../localization/app_language.dart';
import 'post_media_gallery.dart';
import 'comments_sheet.dart';
import '../../domain/community_repository.dart';
import 'post_markdown.dart';
import 'user_avatar.dart';
import 'report_dialog.dart';

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
    this.isAnonymousAuthor = false,
    required this.time,
    required this.text,
    this.price,
    this.collapseText = false,
    this.mediaFirst = false,
    this.compact = false,
    this.showCommunity = true,
    this.communityFirst = false,
    this.onCommunityTap,
    this.showActions = true,
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
    this.repository,
    this.post,
    this.viewerContent = false,
  });

  final CommunityRepository? repository;
  final CommunityPost? post;
  final bool viewerContent;
  final String category;
  final String icon;
  final String community;
  final String author;
  final String? authorAvatarUrl;
  final bool isAnonymousAuthor;
  final String time;
  final String text;
  final String? price;
  final bool collapseText;
  final bool mediaFirst;
  final bool compact;
  final bool showCommunity;
  final bool communityFirst;
  final VoidCallback? onCommunityTap;
  final bool showActions;
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
  final Future<void> Function(String reason, String category, {bool? hidePost})?
  onReport;
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

  Future<
    ({
      int likes,
      int comments,
      bool reacted,
      bool saved,
      bool hidden,
      PostPoll? poll,
    })
  >
  openMedia(
    BuildContext context, {
    int initialIndex = 0,
    int? currentLikes,
    int? currentComments,
    bool? currentReacted,
    bool? currentSaved,
    PostPoll? currentPoll,
  }) async {
    var count = currentLikes ?? likes;
    var commentCount = currentComments ?? comments;
    var liked = currentReacted ?? reacted;
    var isSaved = currentSaved ?? saved;
    var hidden = false;
    var latestPoll = currentPoll ?? poll;
    final cardKey = GlobalKey<_PostCardState>();
    final commentsKey = GlobalKey();
    await openPostMediaViewer(
      context,
      media,
      initialIndex: initialIndex,
      author: context.tr(author),
      actionsBuilder: (viewerContext) => IconButton(
        tooltip: viewerContext.tr('Post options'),
        icon: const Icon(Icons.more_horiz),
        onPressed: () => cardKey.currentState?._menu()._open(viewerContext),
      ),
      contentBuilder: (viewerContext) => Column(
        children: [
          PostCard(
            key: cardKey,
            viewerContent: true,
            category: category,
            icon: icon,
            community: community,
            author: author,
            authorAvatarUrl: authorAvatarUrl,
            isAnonymousAuthor: isAnonymousAuthor,
            time: time,
            text: text,
            price: price,
            promotion: promotion,
            edited: edited,
            collapseText: true,
            compact: true,
            showCommunity: showCommunity,
            showActions: showActions,
            likes: count,
            comments: commentCount,
            reacted: liked,
            saved: isSaved,
            onAuthorTap: onAuthorTap,
            onCommunityTap: onCommunityTap,
            onMentionTap: onMentionTap,
            onReaction: onReaction == null
                ? null
                : (next) async {
                    count = await onReaction!(next);
                    liked = next;
                    return count;
                  },
            onSaved: onSaved == null
                ? null
                : (next) async {
                    await onSaved!(next);
                    isSaved = next;
                  },
            onComments: onComments == null
                ? null
                : () async {
                    if (commentsKey.currentContext != null) {
                      await Scrollable.ensureVisible(
                        commentsKey.currentContext!,
                        duration: const Duration(milliseconds: 250),
                      );
                      return commentCount;
                    }
                    return onComments!();
                  },
            onShare: onShare,
            onReport: onReport == null
                ? null
                : (reason, category, {hidePost}) async {
                    await onReport!(reason, category, hidePost: hidePost);
                    if (hidePost == true) {
                      hidden = true;
                      if (viewerContext.mounted) Navigator.pop(viewerContext);
                    }
                  },
            onEdit: onEdit == null
                ? null
                : () {
                    Navigator.pop(viewerContext);
                    onEdit!();
                  },
            onDelete: onDelete == null
                ? null
                : () async {
                    await onDelete!();
                    if (viewerContext.mounted) Navigator.pop(viewerContext);
                  },
            poll: latestPoll,
            onPollVote: onPollVote == null
                ? null
                : (optionId) async {
                    latestPoll = await onPollVote!(optionId);
                    return latestPoll!;
                  },
          ),
          if (repository != null && post != null && onComments != null)
            PostComments(
              key: commentsKey,
              repository: repository!,
              post: post!,
              inline: true,
              onCountChanged: (value) {
                commentCount = value;
                final state = cardKey.currentState;
                state?._updateCommentCount(value);
              },
            ),
        ],
      ),
    );
    return (
      likes: count,
      comments: commentCount,
      reacted: liked,
      saved: isSaved,
      hidden: hidden,
      poll: latestPoll,
    );
  }

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
  bool _hidden = false;
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
    if (_hidden) return const SizedBox.shrink();
    final accent = categoryColor(widget.category, context);
    final theme = Theme.of(context);
    final communityFirst = widget.communityFirst && widget.showCommunity;
    final authorTap = widget.isAnonymousAuthor ? null : widget.onAuthorTap;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: widget.viewerContent
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(18),
        side: widget.viewerContent
            ? BorderSide.none
            : BorderSide(color: theme.dividerColor.withValues(alpha: .55)),
      ),
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
                    onTap: widget.isAnonymousAuthor ? null : widget.onAuthorTap,
                    customBorder: const CircleBorder(),
                    child: UserAvatar(
                      name: context.tr(widget.author),
                      imageUrl: widget.authorAvatarUrl,
                      radius: widget.compact ? 18 : 21,
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
                          onTap: communityFirst
                              ? widget.onCommunityTap
                              : authorTap,
                          child: Text(
                            communityFirst
                                ? widget.community
                                : context.tr(widget.author),
                            maxLines: communityFirst ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: communityFirst ? authorTap : null,
                          child: Text(
                            '${communityFirst ? '${context.tr(widget.author)} · ' : ''}${widget.time}${widget.edited ? ' · ${context.tr('Edited')}' : ''}${widget.showCommunity && !communityFirst ? ' · ${widget.community}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.viewerContent) _menu(),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.mediaFirst && widget.media.isNotEmpty) ...[
                PostMediaGallery(media: widget.media, onOpen: _openMedia),
                const SizedBox(height: 8),
              ],
              PostMarkdown(
                data: widget.text,
                collapsible: widget.collapseText,
                compact: widget.compact,
                previewLines: widget.compact ? 3 : 5,
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
              if (!widget.mediaFirst && widget.media.isNotEmpty) ...[
                const SizedBox(height: 8),
                PostMediaGallery(media: widget.media, onOpen: _openMedia),
              ] else if (widget.showImage && widget.media.isEmpty) ...[
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
              if (widget.showActions) const SizedBox(height: 2),
              if (widget.showActions)
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
                    const SizedBox(width: 12),
                    _PostAction(
                      icon: CupertinoIcons.arrowshape_turn_up_right,
                      tooltip: context.tr('Share'),
                      value: widget.viewerContent ? context.tr('Share') : null,
                      onTap: widget.onShare,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  _PostMenu _menu() => _PostMenu(
    category: widget.category,
    categoryIcon: widget.icon,
    saved: _saved,
    saving: _savingPost || _deleting,
    onSave: widget.onSaved == null ? null : _toggleSaved,
    onReport: widget.onReport == null ? null : _report,
    onEdit: widget.onEdit,
    onDelete: widget.onDelete == null ? null : _deletePost,
  );

  Future<void> _openMedia(int index) async {
    final result = await widget.openMedia(
      context,
      initialIndex: index,
      currentLikes: _likes,
      currentComments: _comments,
      currentReacted: _reacted,
      currentSaved: _saved,
      currentPoll: _poll,
    );
    if (mounted) {
      setState(() {
        _likes = result.likes;
        _comments = result.comments;
        _reacted = result.reacted;
        _saved = result.saved;
        _hidden = result.hidden;
        _poll = result.poll;
      });
    }
  }

  void _updateCommentCount(int value) {
    if (mounted) setState(() => _comments = value);
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
    final report = await showContentReportDialog(context, title: 'Report post');
    if (report == null || !mounted) return;
    try {
      await widget.onReport!(report.$1, report.$2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Report submitted')),
            action: SnackBarAction(
              label: context.tr('Hide post'),
              onPressed: () async {
                try {
                  await widget.onReport!(report.$1, report.$2, hidePost: true);
                  if (mounted) setState(() => _hidden = true);
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.trError(error))),
                    );
                  }
                }
              },
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
    this.value,
    required this.tooltip,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String? value;
  final String tooltip;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: value == null ? tooltip : '$tooltip, $value',
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
              if (value != null) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value!,
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
            ],
          ),
        ),
      ),
    ),
  );
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({
    required this.category,
    required this.categoryIcon,
    required this.saved,
    required this.saving,
    this.onSave,
    this.onReport,
    this.onEdit,
    this.onDelete,
  });

  final String category;
  final String categoryIcon;
  final bool saved;
  final bool saving;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Future<void> _open(BuildContext context) async {
    final action = await showModalBottomSheet<_PostMenuAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        final accent = categoryColor(category, sheetContext);
        Widget option(
          _PostMenuAction action,
          IconData icon,
          String label, {
          bool destructive = false,
        }) => ListTile(
          leading: Icon(
            icon,
            color: destructive
                ? Theme.of(sheetContext).colorScheme.error
                : null,
          ),
          title: Text(
            sheetContext.tr(label),
            style: destructive
                ? TextStyle(color: Theme.of(sheetContext).colorScheme.error)
                : null,
          ),
          onTap: () => Navigator.pop(sheetContext, action),
        );
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: accent.withValues(alpha: .11),
                    child: Text(
                      categoryIcon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(
                    sheetContext.tr(category),
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onSave != null ||
                    onEdit != null ||
                    onDelete != null ||
                    onReport != null)
                  const Divider(indent: 16, endIndent: 16),
                if (onSave != null)
                  option(
                    _PostMenuAction.save,
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    saved ? 'Unsave post' : 'Save post',
                  ),
                if (onEdit != null)
                  option(
                    _PostMenuAction.edit,
                    Icons.edit_outlined,
                    'Edit post',
                  ),
                if (onDelete != null)
                  option(
                    _PostMenuAction.delete,
                    Icons.delete_outline,
                    'Delete publication',
                    destructive: true,
                  ),
                if (onReport != null)
                  option(
                    _PostMenuAction.report,
                    Icons.flag_outlined,
                    'Report post',
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted) return;
    switch (action) {
      case _PostMenuAction.save:
        onSave?.call();
      case _PostMenuAction.report:
        onReport?.call();
      case _PostMenuAction.edit:
        onEdit?.call();
      case _PostMenuAction.delete:
        onDelete?.call();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr('More options'),
    onPressed: saving ? null : () => _open(context),
    icon: saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.more_horiz),
  );
}

enum _PostMenuAction { save, edit, delete, report }
