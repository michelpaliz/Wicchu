import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/community_avatar.dart';
import '../community/community_profile_page.dart';
import '../community/community_invitations_page.dart';
import '../community/post_detail_page.dart';
import 'admin_management_pages.dart';
import 'admin_review_queues.dart';

typedef _Overview = ({
  Community community,
  List<CommunityPost> posts,
  AdminAttentionSummary attention,
});

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({
    super.key,
    required this.community,
    required this.repository,
  });
  final Community community;
  final CommunityRepository repository;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  late Community _community = widget.community;
  late Future<_Overview> _data = _load();
  bool _showTip = true;
  bool get _canConfigure =>
      _community.myRole == CommunityRole.owner ||
      _community.myRole == CommunityRole.admin;

  Future<_Overview> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.getCommunity(_community.id),
      widget.repository.listPosts(_community.id, sort: 'newest'),
      widget.repository.getAdminAttention(_community.id),
    ]);
    final posts = List<CommunityPost>.of(values[1] as List<CommunityPost>)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (
      community: values[0] as Community,
      posts: posts,
      attention: values[2] as AdminAttentionSummary,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    try {
      await next;
    } catch (_) {
      /* Render the error in the page. */
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _refresh();
  }

  Future<void> _settings() async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunitySettingsPage(
          community: _community,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    if (updated != null) _community = updated;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => Navigator.pop(context, _community)),
      title: Text(context.tr('Overview')),
    ),
    body: FutureBuilder<_Overview>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.trError(snapshot.error!)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data!;
        _community = data.community;
        final colors = Theme.of(context).colorScheme;
        final pending =
            data.attention.pendingPosts +
            data.attention.pendingPromotions +
            data.attention.openReports +
            (_canConfigure ? data.attention.membershipRequests : 0);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  CommunityAvatar(community: _community, radius: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _community.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          context.tr('Community overview'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            context.tr(
                              _community.visibility ==
                                      CommunityVisibility.public
                                  ? 'Public community'
                                  : 'Private community',
                            ),
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('Current statistics'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 320
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _stat(
                        width,
                        Icons.group_outlined,
                        '${_community.memberCount}',
                        'Members',
                        _canConfigure
                            ? () => _open(
                                MemberManagementPage(
                                  community: _community,
                                  repository: widget.repository,
                                ),
                              )
                            : null,
                      ),
                      _stat(
                        width,
                        Icons.article_outlined,
                        '${data.posts.length}',
                        'Posts',
                        _posts,
                      ),
                      _stat(
                        width,
                        Icons.flag_outlined,
                        '${data.attention.openReports}',
                        'Open reports',
                        () => _open(
                          ReportsQueuePage(
                            community: _community,
                            repository: widget.repository,
                          ),
                        ),
                      ),
                      _stat(
                        width,
                        Icons.visibility_outlined,
                        context.tr(_community.visibility.name),
                        'Visibility',
                        _canConfigure ? _settings : null,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primary,
                      child: Icon(
                        pending == 0 ? Icons.check : Icons.pending_actions,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              pending == 0
                                  ? 'All caught up'
                                  : 'Needs your attention',
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              pending == 0
                                  ? 'Nothing needs your attention.'
                                  : 'Review pending work in community administration.',
                            ),
                          ),
                          if (pending > 0)
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, _community),
                              child: Text(context.tr('Manage community')),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Recent posts'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _posts,
                    child: Text(context.tr('View all')),
                  ),
                ],
              ),
              _card(
                Column(
                  children: [
                    if (data.posts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(context.tr('No posts yet.')),
                      ),
                    for (final post in data.posts.take(3))
                      ListTile(
                        leading: Icon(
                          Icons.article_outlined,
                          color: colors.primary,
                        ),
                        title: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          post.text.replaceAll(RegExp(r'[*_#>`~]'), ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatShortDate(post.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _open(
                          PostDetailPage(
                            postId: post.id,
                            initialPost: post,
                            repository: widget.repository,
                            community: _community.name,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _card(
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('Community information'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_canConfigure)
                            TextButton.icon(
                              onPressed: _settings,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: Text(context.tr('Edit')),
                            ),
                        ],
                      ),
                    ),
                    _detail(
                      Icons.location_on_outlined,
                      'Town',
                      _community.town.name,
                    ),
                    _detail(
                      Icons.visibility_outlined,
                      'Visibility',
                      context.tr(_community.visibility.name),
                    ),
                    _detail(
                      Icons.approval_outlined,
                      'Post approval',
                      context.tr(
                        _community.approvalRequired ? 'Required' : 'Automatic',
                      ),
                    ),
                  ],
                ),
              ),
              if (_showTip) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.lightbulb_outline,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Tip'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                'Invite more people to grow your community.',
                              ),
                            ),
                            TextButton(
                              onPressed: () => _open(
                                CommunityInvitationsPage(
                                  community: _community,
                                  repository: widget.repository,
                                ),
                              ),
                              child: Text(context.tr('Invitations')),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('Close'),
                        onPressed: () => setState(() => _showTip = false),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  void _posts() => _open(
    CommunityProfilePage(community: _community, repository: widget.repository),
  );

  Widget _card(Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
      ),
    ),
    child: child,
  );

  Widget _stat(
    double width,
    IconData icon,
    String value,
    String label,
    VoidCallback? onTap,
  ) => SizedBox(
    width: width,
    child: _card(
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(label),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _detail(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(
      context.tr(label),
      style: Theme.of(context).textTheme.bodySmall,
    ),
    subtitle: Text(value, style: Theme.of(context).textTheme.bodyMedium),
    trailing: _canConfigure ? const Icon(Icons.chevron_right) : null,
    onTap: _canConfigure ? _settings : null,
  );
}
