import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/post_card.dart';
import '../profile/member_profile_page.dart';

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

  int _index = 0;
  late final Future<List<CommunityCategory>> _categories = widget.repository
      .listCategories(widget.community.id);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.pop(context, _changed);
    },
    child: FutureBuilder<List<CommunityPost>>(
      future: _posts,
      builder: (context, snapshot) {
        final ready =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final posts = ready
            ? snapshot.data ?? <CommunityPost>[]
            : <CommunityPost>[];
        final index = posts.isEmpty ? 0 : _index.clamp(0, posts.length - 1);
        final post = posts.isEmpty ? null : posts[index];
        final saving = _saving.isNotEmpty;
        final colors = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.tr('Approval queue'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            leading: BackButton(
              onPressed: () => Navigator.pop(context, _changed),
            ),
          ),
          bottomNavigationBar: post == null
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: colors.error,
                              side: BorderSide(color: colors.error),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: saving
                                ? null
                                : () => _moderate(post, approve: false),
                            icon: const Icon(Icons.close),
                            label: Text(context.tr('Reject')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: saving
                                ? null
                                : () => _moderate(post, approve: true),
                            icon: saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(context.tr('Approve')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          body: !ready && !snapshot.hasError
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
              ? Center(
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
                )
              : post == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt, size: 64, color: colors.primary),
                      const SizedBox(height: 16),
                      Text(context.tr('No posts need approval')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr(
                                posts.length == 1
                                    ? '{current} of {total} post'
                                    : '{current} of {total} posts',
                                {
                                  'current': '${index + 1}',
                                  'total': '${posts.length}',
                                },
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: context.tr('Previous post'),
                            onPressed: saving || index == 0
                                ? null
                                : () => setState(() => _index = index - 1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: context.tr('Next post'),
                            onPressed: saving || index == posts.length - 1
                                ? null
                                : () => setState(() => _index = index + 1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: ValueKey(post.id),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF443719)
                                    : const Color(0xFFFFF4DA),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    color: Color(0xFFB58125),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('Pending approval'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.tr('Submitted {time}', {
                                            'time': formatPostTime(
                                              context,
                                              post.createdAt,
                                            ),
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<CommunityCategory>>(
                              future: _categories,
                              builder: (context, categorySnapshot) {
                                final matching =
                                    (categorySnapshot.data ??
                                            <CommunityCategory>[])
                                        .where(
                                          (category) =>
                                              category.id == post.categoryId,
                                        );
                                final category = matching.isEmpty
                                    ? null
                                    : matching.first;
                                return PostCard(
                                  key: ValueKey('preview-${post.id}'),
                                  category: category?.name ?? 'General',
                                  icon: category?.icon ?? '💬',
                                  community: widget.community.name,
                                  author: post.authorName,
                                  authorAvatarUrl: post.authorAvatarUrl,
                                  isAnonymousAuthor: post.isAnonymous,
                                  time: formatPostTime(context, post.createdAt),
                                  text: post.text.replaceAll(
                                    RegExp(r'\n[ \t]*\n+'),
                                    '\n\n',
                                  ),
                                  showCommunity: false,
                                  showActions: false,
                                  onMentionTap: (userId) => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MemberProfilePage(
                                        userId: userId,
                                        repository: widget.repository,
                                      ),
                                    ),
                                  ),
                                  media: post.media,
                                  poll: post.poll,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    ),
  );

  Future<void> _moderate(CommunityPost post, {required bool approve}) async {
    if (_saving.isNotEmpty) return;
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
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }
}
