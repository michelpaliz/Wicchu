import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../admin/admin_dashboard_page.dart';
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
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage>
    with SingleTickerProviderStateMixin {
  late Community _community = widget.community;
  late bool _joined = widget.community.isJoined;
  late final TabController _tabs = TabController(length: 4, vsync: this);
  late Future<List<CommunityMember>> _members;
  late Future<List<CommunityCategory>> _categories;
  late Future<List<CommunityPost>> _posts;
  late Future<CommunityRules> _rules;
  late Future<CommunityHelpfulness> _helpfulness;
  bool _savingMembership = false;
  String? _categoryId;
  bool _savingHelpfulness = false;

  bool get _canManage =>
      _community.myRole == CommunityRole.owner ||
      _community.myRole == CommunityRole.admin ||
      _community.myRole == CommunityRole.moderator;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _helpfulness = widget.repository.getCommunityHelpfulness(_community.id);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trError(error))),
        );
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
                  question: 'Do you find this community helpful?', value: helpful,
                  choices: const {true: 'Yes', false: 'Not really'},
                  onChanged: (value) => setDialogState(() => helpful = value),
                ),
                _SurveyChoice<String>(
                  question: 'Is the information relevant to your local area?', value: locallyRelevant,
                  choices: const {'yes': 'Yes', 'sometimes': 'Sometimes', 'no': 'No'},
                  onChanged: (value) => setDialogState(() => locallyRelevant = value),
                ),
                _SurveyChoice<String>(
                  question: 'Do you feel safe participating here?', value: safeParticipation,
                  choices: const {'yes': 'Yes', 'sometimes': 'Sometimes', 'no': 'No'},
                  onChanged: (value) => setDialogState(() => safeParticipation = value),
                ),
                _SurveyChoice<String>(
                  question: 'Is the community well organized?', value: wellOrganized,
                  choices: const {'yes': 'Yes', 'somewhat': 'Somewhat', 'no': 'No'},
                  onChanged: (value) => setDialogState(() => wellOrganized = value),
                ),
                _SurveyChoice<bool>(
                  question: 'Would you recommend this community to someone nearby?', value: recommend,
                  choices: const {true: 'Yes', false: 'No'},
                  onChanged: (value) => setDialogState(() => recommend = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.tr('Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.tr('Submit'))),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Thanks for your feedback.'))));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    } finally {
      if (mounted) setState(() => _savingHelpfulness = false);
    }
  }

  @override
  void dispose() {
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
          distanceKm: _community.distanceKm,
          rules: _community.rules,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.pop(context, _community),
        icon: const Icon(Icons.arrow_back),
      ),
      title: Text(context.tr('Community profile')),
      actions: [
        IconButton(
          tooltip: context.tr('Share'),
          onPressed: () => shareCommunity(context, _community),
          icon: const Icon(Icons.ios_share_outlined),
        ),
      ],
    ),
    body: NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabHeaderDelegate(
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: context.tr('Posts')),
                Tab(text: context.tr('About')),
                Tab(text: context.tr('Members')),
                Tab(text: context.tr('Media')),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [_postsTab(), _aboutTab(context), _membersTab(), _mediaTab()],
      ),
    ),
  );

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Container(
                color: scheme.primaryContainer,
                child: _community.imageUrl == null
                    ? Icon(
                        Icons.groups_rounded,
                        size: 72,
                        color: scheme.primary,
                      )
                    : Image.network(_community.imageUrl!, fit: BoxFit.cover),
              ),
              Positioned(
                left: 20,
                bottom: -32,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: CommunityAvatar(community: _community, radius: 38),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _community.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_community.town.name} · ${context.trCount(_community.memberCount, singular: '{count} member', plural: '{count} members')}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed:
                          _savingMembership ||
                              _community.myRole == CommunityRole.owner
                          ? null
                          : _toggleMembership,
                      icon: _savingMembership
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_joined ? Icons.check : Icons.add),
                      label: Text(
                        context.tr(
                          _community.myRole == CommunityRole.owner
                              ? 'Owner'
                              : (_joined ? 'Joined' : 'Join'),
                        ),
                      ),
                    ),
                  ),
                  if (_canManage) ...[
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: context.tr('Manage community'),
                      onPressed: _openManagement,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                    ),
                  ],
                ],
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
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(context.tr('All')),
                          selected: _categoryId == null,
                          onSelected: (_) => setState(() => _categoryId = null),
                        ),
                      ),
                      for (final category in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(context.tr(category.name)),
                            selected: _categoryId == category.id,
                            onSelected: (_) =>
                                setState(() => _categoryId = category.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                            onAuthorTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MemberProfilePage(
                                  userId: post.authorId,
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
    padding: const EdgeInsets.all(20),
    children: [
      _Section(
        title: context.tr('Helpful to members'),
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feedback.isPublic)
                  Text(
                    context.tr('{percentage}% of members find this community helpful', {
                      'percentage': '${feedback.helpfulPercentage ?? 0}',
                    }),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(context.trCount(
                    feedback.minimumResponses - feedback.responseCount,
                    singular: '{count} more response is needed to show the community score.',
                    plural: '{count} more responses are needed to show the community score.',
                  )),
                if (feedback.responseCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(context.trCount(
                    feedback.responseCount,
                    singular: 'Based on {count} response',
                    plural: 'Based on {count} responses',
                  )),
                ],
                if (feedback.eligible) ...[
                  const SizedBox(height: 14),
                  Text(context.tr('Do you find this community helpful?')),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, icon: const Icon(Icons.thumb_up_outlined), label: Text(context.tr('Yes'))),
                      ButtonSegment(value: false, icon: const Icon(Icons.thumb_down_outlined), label: Text(context.tr('Not really'))),
                    ],
                    selected: feedback.myVote == null ? const <bool>{} : {feedback.myVote!.helpful},
                    emptySelectionAllowed: true,
                    onSelectionChanged: _savingHelpfulness
                        ? null
                        : (selection) {
                            if (selection.isNotEmpty) _rateHelpfulness(selection.first);
                          },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _savingHelpfulness ? null : () => _openCommunitySurvey(feedback),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(context.tr('Answer the short survey')),
                  ),
                ],
                if (feedback.insights.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(context.tr('Anonymous member insights'), style: Theme.of(context).textTheme.titleSmall),
                  for (final entry in feedback.insights.entries)
                    _DetailRow(
                      icon: Icons.insights_outlined,
                      label: '${context.tr(switch (entry.key) {
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
      _Section(
        title: context.tr('About this community'),
        child: Text(
          _community.description.trim().isEmpty
              ? context.tr('No description provided')
              : _community.description,
        ),
      ),
      _Section(
        title: context.tr('Details'),
        child: Column(
          children: [
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
      FutureBuilder<List<CommunityCategory>>(
        future: _categories,
        builder: (context, snapshot) => _Section(
          title: context.tr('Categories'),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category
                  in snapshot.data ?? const <CommunityCategory>[])
                Chip(
                  label: Text('${category.icon} ${context.tr(category.name)}'),
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
          final rules = snapshot.data?.rules ?? _community.rules;
          return _Section(
            title: context.tr('Community rules'),
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
    ],
  );

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
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PostMediaGallery(media: [item]),
                  ),
                ),
              ),
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
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _SurveyChoice<T> extends StatelessWidget {
  const _SurveyChoice({required this.question, required this.value, required this.choices, required this.onChanged});
  final String question;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: context.tr(question), border: const OutlineInputBorder()),
      items: choices.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(context.tr(entry.value)))).toList(),
      onChanged: (value) { if (value != null) onChanged(value); },
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
  const _TabHeaderDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(color: Theme.of(context).colorScheme.surface, child: tabBar);
  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}
