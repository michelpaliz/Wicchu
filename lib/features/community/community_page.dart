import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../admin/admin_dashboard_page.dart';
import 'category_page.dart';
import 'comments_sheet.dart';
import 'create_post_page.dart';
import 'post_card.dart';
import 'post_detail_page.dart';
import 'community_share.dart';
import 'community_avatar.dart';
import 'community_profile_page.dart';
import 'post_share.dart';
import '../profile/member_profile_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late Future<List<CommunityCategory>> _categories;
  late Future<List<CommunityPost>> _posts;
  late Community _community = widget.community;
  late bool _isJoined = widget.community.isJoined;
  bool _checkingRules = false;

  Community get community => _community;
  CommunityRepository get repository => widget.repository;
  bool get _canManage =>
      community.myRole == CommunityRole.owner ||
      community.myRole == CommunityRole.admin;

  @override
  void initState() {
    super.initState();
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRules());
  }

  void _reload() {
    _categories = repository.listCategories(community.id);
    _posts = repository.listPosts(community.id);
  }

  Future<void> _checkRules() async {
    if (!_isJoined || _checkingRules || !mounted) return;
    _checkingRules = true;
    try {
      final result = await repository.listRules(community.id);
      if (!mounted || !result.acceptanceRequired) return;
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.tr('Community rules')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: result.rules.length,
              itemBuilder: (context, index) {
                final rule = result.rules[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(rule.title),
                  subtitle: Text(rule.description),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.tr('Accept rules')),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (accepted == true) {
        await repository.acceptRules(community.id, result.rulesVersion);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Rules accepted'))),
          );
        }
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      _checkingRules = false;
    }
  }

  Future<void> _createPost() async {
    try {
      final categories = await _categories;
      if (!mounted) return;
      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('No categories found'))),
        );
        return;
      }
      final post = await Navigator.push<CommunityPost>(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePostPage(
            community: community,
            repository: repository,
            categories: categories,
          ),
        ),
      );
      if (post != null && mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _openManagement() async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminDashboardPage(community: community, repository: repository),
      ),
    );
    if (updated != null && mounted) setState(() => _community = updated);
  }

  Future<void> _openProfile() async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          community: community,
          repository: repository,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (updated != null) {
        _community = updated;
        _isJoined = updated.isJoined;
      }
      _reload();
    });
  }

  Future<void> _showMembers() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => FutureBuilder<List<CommunityMember>>(
      future: repository.listMembers(community.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final members = [...?snapshot.data]
          ..sort((a, b) {
            if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
            return a.name.compareTo(b.name);
          });
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr('Members'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final member in members)
              ListTile(
                leading: Badge(
                  isLabelVisible: member.isOnline,
                  backgroundColor: Colors.green,
                  smallSize: 10,
                  child: CircleAvatar(
                    child: Text(
                      member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
                    ),
                  ),
                ),
                title: Text(member.name),
                subtitle: member.isOnline
                    ? Text(context.tr('Online now'))
                    : member.lastActiveAt != null
                    ? Text(context.tr('Active recently'))
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberProfilePage(
                        userId: member.userId,
                        repository: repository,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Community')),
        actions: [
          IconButton(
            tooltip: context.tr('Share'),
            onPressed: () => shareCommunity(context, community),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          try {
            await Future.wait([_categories, _posts]);
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Container(
              height: 156,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (community.imageUrl == null)
                    Icon(
                      Icons.groups_rounded,
                      size: 68,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    Image.network(
                      community.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: CommunityAvatar(
                          community: community,
                          radius: 42,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: community.town.name,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (community.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      community.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.people_outline,
                        label: context.trCount(
                          community.memberCount,
                          singular: '{count} member',
                          plural: '{count} members',
                        ),
                        onTap: _isJoined ? _showMembers : null,
                      ),
                      if (community.myRole != null)
                        _InfoChip(
                          icon: Icons.verified_user_outlined,
                          label: context.tr(
                            community.myRole == CommunityRole.owner
                                ? 'Owner'
                                : community.myRole!.name,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openProfile,
                    icon: const Icon(Icons.info_outline),
                    label: Text(context.tr('View community profile')),
                  ),
                  const SizedBox(height: 18),
                  if (community.myRole != CommunityRole.owner)
                    SizedBox(
                      width: double.infinity,
                      child: _MembershipButton(
                        community: community,
                        repository: repository,
                        onChanged: (joined) =>
                            setState(() {
                              _isJoined = joined;
                              if (joined) {
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _checkRules(),
                                );
                              }
                            }),
                      ),
                    ),
                  if (community.myRole != CommunityRole.owner)
                    const SizedBox(height: 10),
                  if (_isJoined)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _createPost,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.tr('New post')),
                      ),
                    ),
                  if (_canManage) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openManagement,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: Text(context.tr('Community management')),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    context.tr('Categories'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<CommunityCategory>>(
                    future: _categories,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(context.trError(snapshot.error!));
                      }
                      final categories =
                          snapshot.data ?? const <CommunityCategory>[];
                      if (categories.isEmpty) {
                        return Text(context.tr('No categories found'));
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.75,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CategoryPage(
                                    community: community,
                                    category: category,
                                    repository: repository,
                                    canPost: _isJoined,
                                  ),
                                ),
                              ).then((_) => setState(_reload)),
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
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                      if (posts.isEmpty) {
                        return Text(context.tr('No posts found'));
                      }
                      return Column(
                        children: [
                          for (final post in posts) ...[
                            PostCard(
                              collapseText: true,
                              onTap: () =>
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PostDetailPage(
                                        postId: post.id,
                                        repository: repository,
                                        initialPost: post,
                                        community: community.name,
                                      ),
                                    ),
                                  ).then((_) {
                                    if (mounted) setState(_reload);
                                  }),
                              category: 'Post',
                              icon: '💬',
                              community: community.name,
                              author: post.authorName,
                              authorAvatarUrl: post.authorAvatarUrl,
                              onAuthorTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MemberProfilePage(
                                    userId: post.authorId,
                                    repository: repository,
                                  ),
                                ),
                              ),
                              time: formatPostTime(context, post.createdAt),
                              edited: post.editedAt != null,
                              onEdit: post.ownedByMe
                                  ? () async {
                                      await openEditPost(
                                        context,
                                        repository,
                                        post,
                                      );
                                      if (mounted) setState(_reload);
                                    }
                                  : null,
                              onDelete: post.ownedByMe
                                  ? () async {
                                      await repository.deletePost(post.id);
                                      if (mounted) setState(_reload);
                                    }
                                  : null,
                              text: post.text,
                              likes: post.reactionCount,
                              comments: post.commentCount,
                              media: post.media,
                              poll: post.poll,
                              onPollVote: (optionId) =>
                                  repository.voteOnPost(post.id, optionId),
                              promotion: post.promotion,
                              onPromotionImpression: post.promotion == null
                                  ? null
                                  : () => repository.recordPromotionImpression(
                                      post.promotion!.id,
                                    ),
                              onPromotionClick: post.promotion == null
                                  ? null
                                  : () => repository.recordPromotionClick(
                                      post.promotion!.id,
                                    ),
                              reacted: post.reactedByMe,
                              onReaction: (reacted) => repository
                                  .setPostReaction(post.id, reacted: reacted),
                              onComments: () =>
                                  showPostComments(context, repository, post),
                              saved: post.savedByMe,
                              onSaved: (saved) => repository.setPostSaved(
                                post.id,
                                saved: saved,
                              ),
                              onReport: (reason) =>
                                  repository.reportPost(post.id, reason),
                              onShare: () => sharePost(
                                repository,
                                post,
                                communityName: community.name,
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
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _MembershipButton extends StatefulWidget {
  const _MembershipButton({
    required this.community,
    required this.repository,
    required this.onChanged,
  });

  final Community community;
  final CommunityRepository repository;
  final ValueChanged<bool> onChanged;

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
      if (mounted) {
        setState(() => _joined = !_joined);
        widget.onChanged(_joined);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
