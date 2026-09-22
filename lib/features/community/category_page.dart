import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'create_post_page.dart';
import 'comments_sheet.dart';
import 'post_card.dart';
import 'post_detail_page.dart';
import 'post_share.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    required this.community,
    required this.category,
    required this.repository,
    required this.canPost,
  });

  final Community community;
  final CommunityCategory category;
  final CommunityRepository repository;
  final bool canPost;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<List<CommunityPost>> _posts;
  String _sort = 'latest';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _posts = widget.repository.listPosts(
      widget.community.id,
      categoryId: widget.category.id,
      sort: _sort,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _posts;
    } catch (_) {}
  }

  Future<void> _createPost() async {
    final post = await Navigator.push<CommunityPost>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          community: widget.community,
          repository: widget.repository,
          initialCategory: widget.category,
        ),
      ),
    );
    if (post != null && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(widget.category.name))),
      floatingActionButton: widget.canPost
          ? FloatingActionButton.extended(
              onPressed: _createPost,
              icon: const Icon(Icons.add),
              label: Text(
                context.tr(
                  widget.category.name == 'Marketplace'
                      ? 'Sell / Post'
                      : 'Post',
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            Text(
              widget.community.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'latest',
                  label: Text(context.tr('Latest')),
                ),
                ButtonSegment(
                  value: 'popular',
                  label: Text(context.tr('Popular')),
                ),
              ],
              selected: {_sort},
              onSelectionChanged: (selection) => setState(() {
                _sort = selection.first;
                _reload();
              }),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<CommunityPost>>(
              future: _posts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(context.trError(snapshot.error!));
                }
                final posts = snapshot.data ?? const [];
                if (posts.isEmpty) return Text(context.tr('No posts found'));
                return Column(
                  children: [
                    for (final post in posts) ...[
                      PostCard(
                        onTap: () =>
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailPage(
                                  postId: post.id,
                                  repository: widget.repository,
                                  initialPost: post,
                                  category: widget.category.name,
                                  icon: widget.category.icon,
                                  community: widget.community.name,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) setState(_reload);
                            }),
                        category: widget.category.name,
                        icon: widget.category.icon,
                        community: widget.community.name,
                        author: post.authorName,
                        authorAvatarUrl: post.authorAvatarUrl,
                        time: formatPostTime(context, post.createdAt),
                        text: post.text,
                        likes: post.reactionCount,
                        comments: post.commentCount,
                        media: post.media,
                        promotion: post.promotion,
                        onPromotionImpression: post.promotion == null
                            ? null
                            : () => widget.repository.recordPromotionImpression(
                                post.promotion!.id,
                              ),
                        onPromotionClick: post.promotion == null
                            ? null
                            : () => widget.repository.recordPromotionClick(
                                post.promotion!.id,
                              ),
                        reacted: post.reactedByMe,
                        onReaction: (reacted) => widget.repository
                            .setPostReaction(post.id, reacted: reacted),
                        onComments: () =>
                            showPostComments(context, widget.repository, post),
                        saved: post.savedByMe,
                        onSaved: (saved) => widget.repository.setPostSaved(
                          post.id,
                          saved: saved,
                        ),
                        onReport: (reason) =>
                            widget.repository.reportPost(post.id, reason),
                        onShare: () => sharePost(
                          widget.repository,
                          post,
                          communityName: widget.community.name,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
