import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/user_avatar.dart';

class RemovedPostsPage extends StatefulWidget {
  const RemovedPostsPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<RemovedPostsPage> createState() => _RemovedPostsPageState();
}

class _RemovedPostsPageState extends State<RemovedPostsPage> {
  late Future<List<CommunityPost>> _posts;
  final _restoring = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _posts = widget.repository.listRemovedPosts(widget.community.id);
  }

  Future<void> _restore(CommunityPost post) async {
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dialogContext.tr('Restore post')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dialogContext.tr(
                  'The post will be published again and its author will be notified.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                maxLength: 1000,
                maxLines: 3,
                onChanged: (value) => setDialogState(() => reason = value),
                decoration: InputDecoration(
                  labelText: dialogContext.tr('Restoration reason'),
                  helperText: dialogContext.tr(
                    'Explain why the moderation decision is being reversed.',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: reason.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.tr('Restore')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _restoring.add(post.id));
    try {
      await widget.repository.restorePost(
        widget.community.id,
        post.id,
        reason: reason.trim(),
      );
      if (!mounted) return;
      setState(() {
        _restoring.remove(post.id);
        _reload();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Post restored'))));
    } catch (error) {
      if (!mounted) return;
      setState(() => _restoring.remove(post.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Removed posts'))),
    body: FutureBuilder<List<CommunityPost>>(
      future: _posts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.trError(snapshot.error!)),
                TextButton(
                  onPressed: () => setState(_reload),
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          );
        }
        final posts = snapshot.data ?? const <CommunityPost>[];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  WicchuIcons.fileArrowUp,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(context.tr('No removed posts')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _posts;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              final restoring = _restoring.contains(post.id);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          UserAvatar(
                            name: post.authorName,
                            imageUrl: post.authorAvatarUrl,
                            radius: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatShortDate(post.createdAt.toLocal()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        post.text,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (post.media.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.trCount(
                            post.media.length,
                            singular: '{count} media item',
                            plural: '{count} media items',
                          ),
                        ),
                      ],
                      if (post.moderationReason.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${context.tr('Removal reason')}: ${post.moderationReason}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          key: ValueKey('restore-post-${post.id}'),
                          onPressed: restoring ? null : () => _restore(post),
                          icon: restoring
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(WicchuIcons.clockCounterClockwise),
                          label: Text(context.tr('Restore post')),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
