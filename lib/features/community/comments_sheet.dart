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
                  if (snapshot.hasError) return Text(snapshot.error.toString());
                  final comments = snapshot.data ?? const [];
                  _count = comments.length;
                  if (comments.isEmpty) {
                    return Center(child: Text(context.tr('No comments yet')));
                  }
                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(comment.authorName),
                        subtitle: Text(comment.text),
                        trailing: Text(formatPostTime(comment.createdAt)),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 5000,
                    decoration: InputDecoration(
                      hintText: context.tr('Write a comment'),
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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.createComment(widget.post.id, text);
      _controller.clear();
      setState(() {
        _count++;
        _comments = widget.repository.listComments(widget.post.id);
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
