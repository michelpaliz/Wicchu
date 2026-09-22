import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../theme/wicchu_theme.dart';
import '../../localization/app_language.dart';
import 'post_media_gallery.dart';
import 'post_markdown.dart';

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
    required this.time,
    required this.text,
    this.price,
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
  });

  final String category;
  final String icon;
  final String community;
  final String author;
  final String time;
  final String text;
  final String? price;
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

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.likes != widget.likes) _likes = widget.likes;
    if (oldWidget.comments != widget.comments) _comments = widget.comments;
    if (oldWidget.reacted != widget.reacted) _reacted = widget.reacted;
    if (oldWidget.saved != widget.saved) _saved = widget.saved;
  }

  @override
  Widget build(BuildContext context) {
    final accent = categoryColor(widget.category, context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.icon} ${context.tr(widget.category).toUpperCase()} · ${widget.community}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.author} · ${widget.time}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              PostMarkdown(data: widget.text),
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
                const SizedBox(height: 14),
                PostMediaGallery(media: widget.media),
              ] else if (widget.showImage) ...[
                const SizedBox(height: 14),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  _PostAction(
                    icon: _reacted ? Icons.favorite : Icons.favorite_border,
                    value: '$_likes',
                    color: _reacted
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    onTap: widget.onReaction == null || _savingReaction
                        ? null
                        : _toggleReaction,
                  ),
                  const SizedBox(width: 22),
                  _PostAction(
                    icon: Icons.chat_bubble_outline,
                    value: '$_comments',
                    onTap: widget.onComments == null ? null : _openComments,
                  ),
                  const SizedBox(width: 18),
                  _PostAction(
                    icon: Icons.ios_share_outlined,
                    value: context.tr('Share'),
                    onTap: widget.onShare,
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: context.tr(_saved ? 'Unsave post' : 'Save post'),
                    onPressed: widget.onSaved == null || _savingPost
                        ? null
                        : _toggleSaved,
                    icon: Icon(
                      _saved ? Icons.bookmark : Icons.bookmark_border,
                      size: 21,
                    ),
                  ),
                  if (widget.onReport != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.tr('Report post'),
                      onPressed: _report,
                      icon: const Icon(Icons.flag_outlined, size: 21),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.value,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(value),
        ],
      ),
    ),
  );
}
