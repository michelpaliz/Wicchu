import '../../widgets/feed_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../admin/admin_dashboard_page.dart';
import '../admin/admin_management_pages.dart';
import '../profile/member_profile_page.dart';
import 'community_avatar.dart';
import 'community_share.dart';
import 'post_media_gallery.dart';
import 'post_card.dart';
import 'post_detail_page.dart';
import 'post_share.dart';
import 'comments_sheet.dart';
import 'create_post_page.dart';

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({
    super.key,
    required this.community,
    required this.repository,
    this.embedded = false,
    this.postRequest,
    this.onSwitchCommunity,
  });

  final Community community;
  final CommunityRepository repository;
  final bool embedded;
  final Listenable? postRequest;
  final VoidCallback? onSwitchCommunity;

  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage>
    with SingleTickerProviderStateMixin {
  late Community _community = widget.community;
  late bool _joined = widget.community.isJoined;
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<List<CommunityMember>> _members;
  late Future<List<CommunityCategory>> _categories;
  late Future<List<CommunityPost>> _posts;
  late Future<CommunityRules> _rules;
  late Future<CommunityHelpfulness> _helpfulness;
  Future<CommunityWeather?>? _weather;
  bool _savingMembership = false;
  bool _openingComposer = false;
  String? _categoryId;
  int _sectionIndex = 0;
  bool _compactPublish = false;
  bool _savingHelpfulness = false;

  bool get _canManage =>
      _community.myRole == CommunityRole.owner ||
      _community.myRole == CommunityRole.admin ||
      _community.myRole == CommunityRole.moderator;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_sectionChanged);
    widget.postRequest?.addListener(_createPost);
    _reload();
  }

  void _sectionChanged() {
    if (_sectionIndex != _tabs.index) {
      setState(() => _sectionIndex = _tabs.index);
    }
  }

  Widget _categoryFilters() => FutureBuilder<List<CommunityCategory>>(
    future: _categories,
    builder: (context, snapshot) {
      final categories = snapshot.data ?? const <CommunityCategory>[];
      return FeedFilterBar(
        labels: [
          context.tr('All'),
          for (final category in categories) context.tr(category.name),
        ],
        selectedIndex: _categoryId == null
            ? 0
            : categories.indexWhere((c) => c.id == _categoryId) + 1,
        onSelected: (index) => setState(
          () => _categoryId = index == 0 ? null : categories[index - 1].id,
        ),
      );
    },
  );

  void _reload() {
    _helpfulness = widget.repository.getCommunityHelpfulness(_community.id);
    _weather = _community.showWeather
        ? widget.repository.getCommunityWeather(_community.id)
        : null;
    _categories = widget.repository.listCategories(_community.id);
    _rules = _joined
        ? widget.repository.listRules(_community.id)
        : Future.value(
            CommunityRules(
              rules: _community.rules,
              rulesVersion: 0,
              acceptedRulesVersion: 0,
              acceptanceRequired: false,
              canManage: false,
            ),
          );
    _posts = _joined
        ? widget.repository.listPosts(_community.id)
        : Future.value(const <CommunityPost>[]);
    _members = _joined
        ? widget.repository.listMembers(_community.id)
        : Future.value(const <CommunityMember>[]);
  }

  Future<void> _rateHelpfulness(bool helpful) async {
    if (_savingHelpfulness) return;
    setState(() => _savingHelpfulness = true);
    try {
      final result = await widget.repository.setCommunityHelpfulness(
        _community.id,
        helpful: helpful,
      );
      if (!mounted) return;
      setState(() => _helpfulness = Future.value(result));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Thanks for your feedback.'))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingHelpfulness = false);
    }
  }

  Future<void> _openCommunitySurvey(CommunityHelpfulness feedback) async {
    final current = feedback.myVote;
    var helpful = current?.helpful ?? true;
    var locallyRelevant = current?.locallyRelevant ?? 'yes';
    var safeParticipation = current?.safeParticipation ?? 'yes';
    var wellOrganized = current?.wellOrganized ?? 'yes';
    var recommend = current?.recommend ?? true;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Community feedback')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SurveyChoice<bool>(
                  question: 'Do you find this community helpful?',
                  value: helpful,
                  choices: const {true: 'Yes', false: 'Not really'},
                  onChanged: (value) => setDialogState(() => helpful = value),
                ),
                _SurveyChoice<String>(
                  question: 'Is the information relevant to your local area?',
                  value: locallyRelevant,
                  choices: const {
                    'yes': 'Yes',
                    'sometimes': 'Sometimes',
                    'no': 'No',
                  },
                  onChanged: (value) =>
                      setDialogState(() => locallyRelevant = value),
                ),
                _SurveyChoice<String>(
                  question: 'Do you feel safe participating here?',
                  value: safeParticipation,
                  choices: const {
                    'yes': 'Yes',
                    'sometimes': 'Sometimes',
                    'no': 'No',
                  },
                  onChanged: (value) =>
                      setDialogState(() => safeParticipation = value),
                ),
                _SurveyChoice<String>(
                  question: 'Is the community well organized?',
                  value: wellOrganized,
                  choices: const {
                    'yes': 'Yes',
                    'somewhat': 'Somewhat',
                    'no': 'No',
                  },
                  onChanged: (value) =>
                      setDialogState(() => wellOrganized = value),
                ),
                _SurveyChoice<bool>(
                  question:
                      'Would you recommend this community to someone nearby?',
                  value: recommend,
                  choices: const {true: 'Yes', false: 'No'},
                  onChanged: (value) => setDialogState(() => recommend = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Submit')),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) return;
    setState(() => _savingHelpfulness = true);
    try {
      final result = await widget.repository.setCommunityHelpfulness(
        _community.id,
        helpful: helpful,
        locallyRelevant: locallyRelevant,
        safeParticipation: safeParticipation,
        wellOrganized: wellOrganized,
        recommend: recommend,
      );
      if (!mounted) return;
      setState(() => _helpfulness = Future.value(result));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Thanks for your feedback.'))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingHelpfulness = false);
    }
  }

  @override
  void dispose() {
    widget.postRequest?.removeListener(_createPost);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleMembership() async {
    if (_savingMembership || _community.myRole == CommunityRole.owner) return;
    setState(() => _savingMembership = true);
    try {
      if (_joined) {
        await widget.repository.leaveCommunity(_community.id);
      } else {
        await widget.repository.joinCommunity(_community.id);
      }
      if (!mounted) return;
      setState(() {
        _joined = !_joined;
        final nextMemberCount = _community.memberCount + (_joined ? 1 : -1);
        _community = Community(
          id: _community.id,
          name: _community.name,
          description: _community.description,
          town: _community.town,
          visibility: _community.visibility,
          createdBy: _community.createdBy,
          createdAt: _community.createdAt,
          imageUrl: _community.imageUrl,
          memberCount: nextMemberCount < 0 ? 0 : nextMemberCount,
          myRole: _joined ? CommunityRole.member : null,
          approvalRequired: _community.approvalRequired,
          showWeather: _community.showWeather,
          distanceKm: _community.distanceKm,
          rules: _community.rules,
          links: _community.links,
        );
        _reload();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingMembership = false);
    }
  }

  Future<void> _openManagement() async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboardPage(
          community: _community,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        if (updated != null) _community = updated;
        _reload();
      });
    }
  }

  Future<void> _createPost() async {
    if (_openingComposer || _savingMembership) return;
    if (!_joined) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Join a community before creating a post.')),
        ),
      );
      return;
    }
    setState(() => _openingComposer = true);
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
            community: _community,
            repository: widget.repository,
            categories: categories,
            initialCategory: categories
                .where((c) => c.id == _categoryId)
                .firstOrNull,
          ),
        ),
      );
      if (post != null && mounted) {
        setState(() {
          // Keep the new publication visible if its category changed in the composer.
          if (_categoryId != null) _categoryId = post.categoryId;
          _reload();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _openingComposer = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: !widget.embedded && _joined && _sectionIndex == 0
        ? FloatingActionButton.extended(
            onPressed: _openingComposer || _savingMembership
                ? null
                : _createPost,
            icon: _openingComposer
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            isExtended: !_compactPublish,
            tooltip: context.tr('Publish'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            label: Text(context.tr('Publish')),
          )
        : null,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: widget.embedded
          ? null
          : IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.pop(context, _community),
              icon: const Icon(Icons.arrow_back),
            ),
      title: widget.onSwitchCommunity == null
          ? Text(_community.name, maxLines: 1, overflow: TextOverflow.ellipsis)
          : InkWell(
              onTap: widget.onSwitchCommunity,
              borderRadius: BorderRadius.circular(12),
              child: Tooltip(
                message: context.tr('Choose a community'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _community.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
      actions: [
        IconButton(
          tooltip: context.tr('Share'),
          onPressed: () => shareCommunity(context, _community),
          icon: const Icon(Icons.ios_share_outlined),
        ),
        PopupMenuButton<String>(
          key: const ValueKey('community-profile-menu'),
          tooltip: context.tr('More options'),
          onSelected: (value) {
            if (value == 'media') {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(context.tr('Media'))),
                    body: _mediaTab(),
                  ),
                ),
              );
            } else {
              _editCommunity();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'media', child: Text(context.tr('Media'))),
            if (_community.myRole == CommunityRole.owner ||
                _community.myRole == CommunityRole.admin)
              PopupMenuItem(
                value: 'edit',
                child: Text(context.tr('Edit community')),
              ),
          ],
        ),
      ],
    ),
    body: NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        final delta = notification.scrollDelta ?? 0;
        if (delta.abs() > 1) {
          final compact = delta > 0;
          if (compact != _compactPublish) {
            setState(() => _compactPublish = compact);
          }
        }
        return false;
      },
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _tabs,
                    builder: (context, _) => FeedFilterBar(
                      style: FeedNavigationStyle.underline,
                      labels: [
                        context.tr('Posts'),
                        context.tr('About'),
                        context.tr('Members'),
                      ],
                      selectedIndex: _tabs.index,
                      onSelected: _tabs.animateTo,
                    ),
                  ),
                  if (_sectionIndex == 0 && _joined) _categoryFilters(),
                ],
              ),
              height: _sectionIndex == 0 && _joined ? 96 : 48,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [_postsTab(), _aboutTab(context), _membersTab()],
        ),
      ),
    ),
  );

  Future<void> _editCommunity() async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunitySettingsPage(
          community: _community,
          repository: widget.repository,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _community = updated;
        _reload();
      });
    }
  }

  Widget _expandableCommunityImage(Widget child) {
    final url = _community.imageUrl;
    if (url == null || url.trim().isEmpty) return child;
    return Semantics(
      button: true,
      label: context.tr('View community image'),
      child: Tooltip(
        message: context.tr('View community image'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openPostMediaViewer(context, [
            PostMedia(url: url, type: 'image'),
          ]),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOwner = _community.myRole == CommunityRole.owner;
    return Column(
      children: [
        SizedBox(
          height: _community.imageUrl == null ? 96 : 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _expandableCommunityImage(
                ColoredBox(
                  color: scheme.primaryContainer,
                  child: _community.imageUrl == null
                      ? null
                      : Image.network(
                          _community.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                ),
              ),
              if (_community.myRole == CommunityRole.owner ||
                  _community.myRole == CommunityRole.admin)
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: FilledButton.icon(
                    onPressed: _editCommunity,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(context.tr('Edit')),
                  ),
                ),
              Positioned(
                left: 16,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: _expandableCommunityImage(
                    CommunityAvatar(community: _community, radius: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _community.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.trCount(_community.memberCount, singular: '{count} member', plural: '{count} members')} · ${context.tr(_community.visibility == CommunityVisibility.public ? 'Public community' : 'Private community')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isOwner)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 14, color: scheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('Owner'),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: scheme.primary),
                          ),
                        ],
                      )
                    else
                      TextButton.icon(
                        onPressed: _savingMembership ? null : _toggleMembership,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: _savingMembership
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(_joined ? Icons.check : Icons.add, size: 16),
                        label: Text(context.tr(_joined ? 'Joined' : 'Join')),
                      ),
                  ],
                ),
              ),
              if (_canManage)
                IconButton(
                  tooltip: context.tr('Manage community'),
                  onPressed: _openManagement,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _refreshPosts() async {
    setState(_reload);
    try {
      await _posts;
    } catch (_) {}
  }

  Widget _postsTab() {
    if (!_joined) {
      return Center(child: Text(context.tr('Join to view community posts.')));
    }
    return FutureBuilder<List<CommunityCategory>>(
      future: _categories,
      builder: (context, categorySnapshot) {
        final categories = categorySnapshot.data ?? const <CommunityCategory>[];
        return RefreshIndicator(
          onRefresh: _refreshPosts,
          child: CustomScrollView(
            key: const PageStorageKey('community-profile-posts'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              FutureBuilder<List<CommunityPost>>(
                future: _posts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Text(context.trError(snapshot.error!)),
                          TextButton(
                            onPressed: _refreshPosts,
                            child: Text(context.tr('Retry')),
                          ),
                        ],
                      ),
                    );
                  }
                  final posts = (snapshot.data ?? const <CommunityPost>[])
                      .where(
                        (post) =>
                            _categoryId == null ||
                            post.categoryId == _categoryId,
                      )
                      .toList();
                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(context.tr('No posts found')),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final category = categories
                            .where((c) => c.id == post.categoryId)
                            .firstOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PostCard(
                            key: ValueKey(post.id),
                            collapseText: true,
                            showCommunity: false,
                            onTap: () =>
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostDetailPage(
                                      postId: post.id,
                                      repository: widget.repository,
                                      initialPost: post,
                                      category: category?.name ?? 'General',
                                      icon: category?.icon ?? '💬',
                                      community: _community.name,
                                    ),
                                  ),
                                ).then((_) {
                                  if (mounted) setState(_reload);
                                }),
                            category: category?.name ?? 'General',
                            icon: category?.icon ?? '💬',
                            community: _community.name,
                            author: post.authorName,
                            authorAvatarUrl: post.authorAvatarUrl,
                            isAnonymousAuthor: post.isAnonymous,
                            onAuthorTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MemberProfilePage(
                                  userId: post.authorId,
                                  repository: widget.repository,
                                ),
                              ),
                            ),
                            onMentionTap: (userId) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MemberProfilePage(
                                  userId: userId,
                                  repository: widget.repository,
                                ),
                              ),
                            ),
                            time: formatPostTime(context, post.createdAt),
                            edited: post.editedAt != null,
                            onEdit: post.ownedByMe
                                ? () async {
                                    await openEditPost(
                                      context,
                                      widget.repository,
                                      post,
                                    );
                                    if (mounted) setState(_reload);
                                  }
                                : null,
                            onDelete: post.ownedByMe
                                ? () async {
                                    await widget.repository.deletePost(post.id);
                                    if (mounted) setState(_reload);
                                  }
                                : null,
                            text: post.text,
                            likes: post.reactionCount,
                            comments: post.commentCount,
                            media: post.media,
                            poll: post.poll,
                            onPollVote: (optionId) =>
                                widget.repository.voteOnPost(post.id, optionId),
                            promotion: post.promotion,
                            onPromotionImpression: post.promotion == null
                                ? null
                                : () => widget.repository
                                      .recordPromotionImpression(
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
                            onComments: () => showPostComments(
                              context,
                              widget.repository,
                              post,
                            ),
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
                              communityName: _community.name,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _aboutTab(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
    children: [
      if (_community.showWeather && _weather != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FutureBuilder<CommunityWeather?>(
            future: _weather,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('Weather is temporarily unavailable.'),
                      ),
                    ),
                  ],
                );
              }
              final weather = snapshot.data;
              if (weather == null) return const SizedBox.shrink();
              return Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.07),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _weatherIcon(weather.weatherCode, weather.isDay),
                        size: 46,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather.temperature.round()}°C · ${context.tr(weather.description)}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              context.tr('High {high}° · Low {low}°', {
                                'high': '${weather.maxTemperature.round()}',
                                'low': '${weather.minTemperature.round()}',
                              }),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              weather.townName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (weather.observedAt != null)
                                  context.tr('Updated {time}', {
                                    'time': TimeOfDay.fromDateTime(
                                      weather.observedAt!.toLocal(),
                                    ).format(context),
                                  }),
                                weather.provider,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      _Section(
        title: context.tr('About {name}', {'name': _community.name}),
        icon: Icons.article_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                _community.description.trim().isEmpty
                    ? context.tr('No description provided')
                    : _community.description,
              ),
            ),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: _community.town.name,
            ),
            _DetailRow(
              icon: _community.visibility == CommunityVisibility.public
                  ? Icons.public
                  : Icons.lock_outline,
              label: context.tr(
                _community.visibility == CommunityVisibility.public
                    ? 'Public community'
                    : 'Private community',
              ),
            ),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: context.tr('Created {date}', {
                'date': MaterialLocalizations.of(
                  context,
                ).formatMediumDate(_community.createdAt.toLocal()),
              }),
            ),
          ],
        ),
      ),
      _Section(
        title: context.tr('Community rating'),
        icon: Icons.star_rounded,
        iconColor: Colors.amber.shade700,
        child: FutureBuilder<CommunityHelpfulness>(
          future: _helpfulness,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return Text(context.trError(snapshot.error!));
            }
            final feedback = snapshot.data!;
            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 12),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                feedback.isPublic
                    ? context.tr(
                        '{percentage}% of members find this community helpful',
                        {'percentage': '${feedback.helpfulPercentage ?? 0}'},
                      )
                    : context.trCount(
                        (feedback.minimumResponses - feedback.responseCount)
                            .clamp(0, feedback.minimumResponses),
                        singular:
                            '{count} more response is needed to show the community score.',
                        plural:
                            '{count} more responses are needed to show the community score.',
                      ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              children: [
                if (feedback.eligible) ...[
                  const SizedBox(height: 14),
                  Text(context.tr('Do you find this community helpful?')),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.thumb_up_outlined),
                        label: Text(context.tr('Yes')),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.thumb_down_outlined),
                        label: Text(context.tr('Not really')),
                      ),
                    ],
                    selected: feedback.myVote == null
                        ? const <bool>{}
                        : {feedback.myVote!.helpful},
                    emptySelectionAllowed: true,
                    onSelectionChanged: _savingHelpfulness
                        ? null
                        : (selection) {
                            if (selection.isNotEmpty) {
                              _rateHelpfulness(selection.first);
                            }
                          },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _savingHelpfulness
                        ? null
                        : () => _openCommunitySurvey(feedback),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(context.tr('Answer the short survey')),
                  ),
                ],
                if (feedback.insights.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    context.tr('Anonymous member insights'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final entry in feedback.insights.entries)
                    _DetailRow(
                      icon: Icons.insights_outlined,
                      label:
                          '${context.tr(switch (entry.key) {
                            'locallyRelevant' => 'Locally relevant',
                            'safeParticipation' => 'Safe to participate',
                            'wellOrganized' => 'Well organized',
                            _ => 'Would recommend',
                          })}: ${entry.value.yesPercentage ?? 0}%',
                    ),
                ],
              ],
            );
          },
        ),
      ),
      FutureBuilder<List<CommunityCategory>>(
        future: _categories,
        builder: (context, snapshot) => _Section(
          title: context.tr('Categories'),
          icon: Icons.sell_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category
                  in snapshot.data ?? const <CommunityCategory>[])
                ActionChip(
                  label: Text(context.tr(category.name)),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  onPressed: () => setState(() {
                    _categoryId = category.id;
                    _tabs.animateTo(0);
                  }),
                ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      FutureBuilder<CommunityRules>(
        future: _rules,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _Section(
              title: context.tr('Community rules'),
              icon: Icons.shield_outlined,
              child: const LinearProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return _Section(
              title: context.tr('Community rules'),
              icon: Icons.shield_outlined,
              child: Text(context.trError(snapshot.error!)),
            );
          }
          final rules = snapshot.data?.rules ?? _community.rules;
          return _Section(
            title: context.tr('Community rules'),
            icon: Icons.shield_outlined,
            child: rules.isEmpty
                ? Text(context.tr('No community rules have been added yet.'))
                : Column(
                    children: [
                      for (final (index, rule) in rules.indexed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(rule.title),
                          subtitle: rule.description.isEmpty
                              ? null
                              : Text(rule.description),
                        ),
                    ],
                  ),
          );
        },
      ),
      _Section(
        title: context.tr('Useful links'),
        icon: Icons.link,
        child: Column(
          children: [
            for (final link in _community.links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(link.label),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => launchUrl(
                  Uri.parse(link.url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.map_outlined),
              title: Text(context.tr('Directions')),
              trailing: const Icon(Icons.open_in_new, size: 20),
              onTap: _openDirections,
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _openDirections() async {
    final destination =
        '${_community.town.name}, ${_community.town.countryCode}';
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Unable to open link');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Unable to open link. Please try again.')),
          ),
        );
      }
    }
  }

  IconData _weatherIcon(int code, bool isDay) {
    if (code == 0) {
      return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
    }
    if (code <= 3) return Icons.cloud_outlined;
    if (code == 45 || code == 48) return Icons.foggy;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.water_drop_outlined;
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return Icons.ac_unit;
    }
    if (code >= 95) return Icons.thunderstorm_outlined;
    return Icons.cloud_outlined;
  }

  Widget _membersTab() {
    if (!_joined) {
      return Center(child: Text(context.tr('Join to view community members.')));
    }
    return FutureBuilder<List<CommunityMember>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final members = [...?snapshot.data]
          ..sort((a, b) {
            final aLeader =
                a.role == CommunityRole.owner ||
                a.role == CommunityRole.admin ||
                a.role == CommunityRole.moderator;
            final bLeader =
                b.role == CommunityRole.owner ||
                b.role == CommunityRole.admin ||
                b.role == CommunityRole.moderator;
            if (aLeader != bLeader) return aLeader ? -1 : 1;
            if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
            return a.name.compareTo(b.name);
          });
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: Badge(
                isLabelVisible: member.isOnline,
                backgroundColor: Colors.green,
                child: CircleAvatar(
                  backgroundImage: member.avatarUrl == null
                      ? null
                      : NetworkImage(member.avatarUrl!),
                  child: member.avatarUrl == null
                      ? Text(
                          member.name.isEmpty
                              ? '?'
                              : member.name[0].toUpperCase(),
                        )
                      : null,
                ),
              ),
              title: Text(member.name),
              subtitle: Text(
                context.tr(
                  member.role == CommunityRole.owner
                      ? 'Owner'
                      : member.role.name,
                ),
              ),
              trailing: member.isOnline
                  ? Text(
                      context.tr('Online now'),
                      style: const TextStyle(color: Colors.green),
                    )
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberProfilePage(
                    userId: member.userId,
                    repository: widget.repository,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _mediaTab() {
    if (!_joined) {
      return Center(child: Text(context.tr('Join to view community media.')));
    }
    return FutureBuilder<List<CommunityPost>>(
      future: _posts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final media = (snapshot.data ?? const <CommunityPost>[])
            .expand((post) => post.media)
            .toList(growable: false);
        if (media.isEmpty) {
          return Center(child: Text(context.tr('No media yet')));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: media.length,
          itemBuilder: (context, index) {
            final item = media[index];
            return InkWell(
              onTap: () =>
                  openPostMediaViewer(context, media, initialIndex: index),
              child: item.type == 'image'
                  ? Image.network(item.url, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: const Icon(Icons.play_circle_outline, size: 40),
                    ),
            );
          },
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
  });
  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: iconColor ?? theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SurveyChoice<T> extends StatelessWidget {
  const _SurveyChoice({
    required this.question,
    required this.value,
    required this.choices,
    required this.onChanged,
  });
  final String question;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: context.tr(question),
        border: const OutlineInputBorder(),
      ),
      items: choices.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(context.tr(entry.value)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabHeaderDelegate(this.tabBar, {this.height = 48});
  final double height;
  final Widget tabBar;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(color: Theme.of(context).colorScheme.surface, child: tabBar);
  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar || oldDelegate.height != height;
}
