import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/post_card.dart';

class PendingPostsPage extends StatefulWidget {
  const PendingPostsPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<PendingPostsPage> createState() => _PendingPostsPageState();
}

class _PendingPostsPageState extends State<PendingPostsPage> {
  late Future<List<CommunityPost>> _posts;
  final _saving = <String>{};
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _posts = widget.repository.listPendingPosts(widget.community.id);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.pop(context, _changed);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Posts awaiting approval')),
        leading: BackButton(onPressed: () => Navigator.pop(context, _changed)),
      ),
      body: FutureBuilder<List<CommunityPost>>(
        future: _posts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final posts = snapshot.data ?? const [];
          if (posts.isEmpty) {
            return Center(child: Text(context.tr('No posts need approval')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              final saving = _saving.contains(post.id);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(formatPostTime(post.createdAt)),
                      const SizedBox(height: 14),
                      Text(post.text),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => _moderate(post, approve: false),
                            child: Text(context.tr('Reject')),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: saving
                                ? null
                                : () => _moderate(post, approve: true),
                            child: saving
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(context.tr('Approve')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );

  Future<void> _moderate(CommunityPost post, {required bool approve}) async {
    setState(() => _saving.add(post.id));
    try {
      await widget.repository.moderatePost(
        widget.community.id,
        post.id,
        approve: approve,
      );
      if (mounted) {
        setState(() {
          _changed = true;
          _saving.remove(post.id);
          _reload();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving.remove(post.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
