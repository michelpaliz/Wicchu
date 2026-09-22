import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../admin/admin_dashboard_page.dart';
import 'category_page.dart';
import 'comments_sheet.dart';
import 'post_card.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(community.name),
        actions: [
          if (community.myRole == CommunityRole.owner ||
              community.myRole == CommunityRole.admin)
            IconButton(
              tooltip: context.tr('Community management'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminDashboardPage(
                    community: community,
                    repository: repository,
                  ),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.landscape_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  community.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('{count} members', {
                    'count': '${community.memberCount}',
                  }),
                ),
                const SizedBox(height: 6),
                Text(context.tr(community.description)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _MembershipButton(
                      community: community,
                      repository: repository,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text(context.tr('Share')),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  context.tr('Categories'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                FutureBuilder<List<CommunityCategory>>(
                  future: repository.listCategories(community.id),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? const [];
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.6,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategoryPage(
                                  community: community,
                                  category: category,
                                  repository: repository,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Text(
                                    category.icon,
                                    style: const TextStyle(fontSize: 21),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.tr(category.name),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 30),
                Text(
                  context.tr('Latest posts'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                FutureBuilder<List<CommunityPost>>(
                  future: repository.listPosts(community.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(snapshot.error.toString());
                    }
                    final posts = snapshot.data ?? const [];
                    if (posts.isEmpty) {
                      return Text(context.tr('No posts found'));
                    }
                    return Column(
                      children: [
                        for (final post in posts) ...[
                          PostCard(
                            category: 'Post',
                            icon: '💬',
                            community: community.name,
                            author: post.authorName,
                            time: formatPostTime(post.createdAt),
                            text: post.text,
                            likes: post.reactionCount,
                            comments: post.commentCount,
                            media: post.media,
                            reacted: post.reactedByMe,
                            onReaction: (reacted) => repository.setPostReaction(
                              post.id,
                              reacted: reacted,
                            ),
                            onComments: () =>
                                showPostComments(context, repository, post),
                            saved: post.savedByMe,
                            onSaved: (saved) =>
                                repository.setPostSaved(post.id, saved: saved),
                            onReport: (reason) =>
                                repository.reportPost(post.id, reason),
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
        ],
      ),
    );
  }
}

class _MembershipButton extends StatefulWidget {
  const _MembershipButton({required this.community, required this.repository});

  final Community community;
  final CommunityRepository repository;

  @override
  State<_MembershipButton> createState() => _MembershipButtonState();
}

class _MembershipButtonState extends State<_MembershipButton> {
  late bool _joined = widget.community.isJoined;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.community.myRole == CommunityRole.owner;
    return FilledButton.tonalIcon(
      onPressed: _saving || isOwner ? null : _toggle,
      icon: _saving
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_joined ? Icons.check : Icons.add),
      label: Text(
        context.tr(isOwner ? 'Owner' : (_joined ? 'Joined' : 'Join')),
      ),
    );
  }

  Future<void> _toggle() async {
    setState(() => _saving = true);
    try {
      if (_joined) {
        await widget.repository.leaveCommunity(widget.community.id);
      } else {
        await widget.repository.joinCommunity(widget.community.id);
      }
      if (mounted) setState(() => _joined = !_joined);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
