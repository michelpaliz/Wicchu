import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'post_card.dart';

Future<int?> showPostComments(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post,
) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _CommentsSheet(repository: repository, post: post),
);

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.repository, required this.post});

  final CommunityRepository repository;
  final CommunityPost post;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  late Future<List<Comment>> _comments = widget.repository.listComments(
    widget.post.id,
  );
  int _count = 0;
  bool _saving = false;
  Comment? _replyingTo;
  final Set<String> _savingReactions = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.pop(context, _count);
    },
    child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Comments'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, _count),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<List<Comment>>(
                future: _comments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(context.trError(snapshot.error!));
                  }
                  final comments = snapshot.data ?? const [];
                  _count = comments.length;
                  if (comments.isEmpty) {
                    return Center(child: Text(context.tr('No comments yet')));
                  }
                  final ids = comments.map((comment) => comment.id).toSet();
                  final roots = comments
                      .where((comment) => comment.parentCommentId == null || !ids.contains(comment.parentCommentId))
                      .toList();
                  return ListView.builder(
                    itemCount: roots.length,
                    itemBuilder: (context, index) {
                      final comment = roots[index];
                      final replies = comments.where((item) => item.parentCommentId == comment.id);
                      return Column(
                        children: [
                          _commentTile(comment, canReply: true),
                          for (final reply in replies)
                            Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: _commentTile(reply, canReply: false),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingTo != null)
              Row(
                children: [
                  Expanded(child: Text(context.tr('Replying to {name}', {'name': _replyingTo!.authorName}))),
                  IconButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 5000,
                    decoration: InputDecoration(
                      hintText: context.tr(_replyingTo == null ? 'Write a comment' : 'Write a reply'),
                      counterText: '',
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _commentTile(Comment comment, {required bool canReply}) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
    title: Text(comment.authorName),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(comment.text),
        Row(
          children: [
            TextButton.icon(
              onPressed: _savingReactions.contains(comment.id) ? null : () => _toggleReaction(comment),
              icon: Icon(comment.reactedByMe ? Icons.favorite : Icons.favorite_border, size: 18),
              label: Text(comment.reactionCount == 0 ? context.tr('Like') : '${comment.reactionCount}'),
            ),
            if (canReply)
              TextButton(
                onPressed: () => setState(() => _replyingTo = comment),
                child: Text(context.tr('Reply')),
              ),
          ],
        ),
      ],
    ),
    trailing: Text(formatPostTime(context, comment.createdAt)),
  );

  Future<void> _toggleReaction(Comment comment) async {
    setState(() => _savingReactions.add(comment.id));
    try {
      await widget.repository.setCommentReaction(comment.id, reacted: !comment.reactedByMe);
      if (!mounted) return;
      setState(() {
        _savingReactions.remove(comment.id);
        _comments = widget.repository.listComments(widget.post.id);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingReactions.remove(comment.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createComment(
        widget.post.id,
        text,
        parentCommentId: _replyingTo?.id,
      );
      _controller.clear();
      setState(() {
        _replyingTo = null;
        _count++;
        _comments = widget.repository.listComments(widget.post.id);
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
