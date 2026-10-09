import 'package:wicchu/theme/wicchu_icons.dart';
import '../../widgets/explore_result_card.dart';
import 'open_post_media.dart';
import '../../widgets/profile_link_button.dart';
import 'post_collection_page.dart';
import '../../widgets/profile_post_grid.dart';
import '../../widgets/wicchu_network_image.dart';
import '../../widgets/block_visibility_listener.dart';
import '../../widgets/profile_accent_picker.dart';
import 'business_service_icon.dart';
import 'post_rules_review_page.dart';
import 'user_avatar.dart';
import 'dart:async';

import 'category_empty_state.dart';
import '../../widgets/feed_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/wicchu_urls.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../admin/admin_dashboard_page.dart';
import '../admin/admin_management_pages.dart';
import '../admin/official_links_page.dart';
import '../chat/direct_chat_pages.dart';
import '../profile/member_profile_page.dart';
import 'community_avatar.dart';
import 'community_share.dart';
import 'community_invitations_page.dart';
import 'post_media_gallery.dart';
import 'post_card.dart';
import 'report_dialog.dart';
import 'post_share.dart';
import 'comments_sheet.dart';
import 'create_post_page.dart';

enum CommunityScreen { feed, information, members, rules, links, rating }

class CommunityProfilePage extends StatefulWidget {
  const CommunityProfilePage({
    super.key,
    required this.community,
    required this.repository,
    this.embedded = false,
    this.postRequest,
    this.onSwitchCommunity,
    this.onAccountMenu,
    this.onCommunityUpdated,
    this.screen = CommunityScreen.feed,
    this.showAdministration = false,
  });

  final CommunityScreen screen;
  final bool showAdministration;
  final Community community;
  final CommunityRepository repository;
  final bool embedded;
  final Listenable? postRequest;
  final VoidCallback? onSwitchCommunity;
  final VoidCallback? onAccountMenu;
  final ValueChanged<Community>? onCommunityUpdated;

  @override
  State<CommunityProfilePage> createState() => _CommunityProfilePageState();
}

class _CommunityProfilePageState extends State<CommunityProfilePage>
    with BlockVisibilityListener<CommunityProfilePage> {
  @override
  CommunityRepository get visibilityRepository => widget.repository;
  @override
  void reloadBlockVisibility() {
    setState(_reload);
  }

  late Community _community = widget.community;
  late bool _joined = widget.community.isJoined;
  late Future<List<CommunityMember>> _members;
  late Future<List<CommunityCategory>> _categories;
  late Future<List<CommunityPost>> _posts;
  late Future<CommunityRules> _rules;
  late Future<CommunityHelpfulness> _helpfulness;
  Future<CommunityWeather?>? _weather;
  bool _savingMembership = false;
  bool _savingLinks = false;
  bool _openingComposer = false;
  Future<WicchuProfile>? _composerProfile;
  String? _categoryId;
  late int _memberFilter = widget.showAdministration ? 1 : 0;
  bool _descriptionExpanded = true;
  bool _headerDescriptionExpanded = false;
  String _memberQuery = '';
  bool _searchMembers = false;
  bool _savingHelpfulness = false;
  bool _submittingBanAppeal = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchingPosts = false;

  bool get _canManage =>
      _community.myRole == CommunityRole.owner ||
      _community.myRole == CommunityRole.admin ||
      _community.myRole == CommunityRole.moderator;
  bool get _canInviteToCommunity =>
      !_community.isPublicProfile &&
      _joined &&
      (_canManage || _community.visibility == CommunityVisibility.public);
  bool get _canViewPosts =>
      !_community.isBanned &&
      (_joined || _community.visibility == CommunityVisibility.public);
  bool get _canPublish => _joined && _community.canPublish;
  String _spaceText(String communityText) {
    if (!_community.isPublicProfile) return communityText;
    final business =
        _community.profileCategory == ProfileCategory.localBusiness;
    return switch (communityText) {
      'Community rating' => business ? 'Business rating' : 'Profile rating',
      'Community rules' => business ? 'Business rules' : 'Profile rules',
      'No community rules have been added yet.' =>
        business
            ? 'No business rules have been added yet.'
            : 'No profile rules have been added yet.',
      'Do you find this community helpful?' =>
        business
            ? 'Do you find this business helpful?'
            : 'Do you find this profile helpful?',
      '{percentage}% of members find this community helpful' =>
        business
            ? '{percentage}% of followers find this business helpful'
            : '{percentage}% of followers find this profile helpful',
      '{count} more response is needed to show the community score.' =>
        business
            ? '{count} more response is needed to show the business score.'
            : '{count} more response is needed to show the profile score.',
      '{count} more responses are needed to show the community score.' =>
        business
            ? '{count} more responses are needed to show the business score.'
            : '{count} more responses are needed to show the profile score.',
      'Community feedback' =>
        business ? 'Business feedback' : 'Profile feedback',
      'Is the community well organized?' =>
        business
            ? 'Is the business page well organized?'
            : 'Is the profile well organized?',
      'Would you recommend this community to someone nearby?' =>
        business
            ? 'Would you recommend this business to someone nearby?'
            : 'Would you recommend this profile to someone nearby?',
      'Anonymous member insights' =>
        business
            ? 'Anonymous follower insights'
            : 'Anonymous follower insights',
      _ => communityText,
    };
  }

  String get _publicWebsiteUrl =>
      WicchuUrls.community(_community.id, _community.slug);

  @override
  void initState() {
    super.initState();
    widget.postRequest?.addListener(_createPost);
    _reload();
    _refreshCommunity();
  }

  Future<void> _refreshCommunity() async {
    final previous = _community;
    try {
      final updated = await widget.repository.getCommunity(previous.id);
      if (!mounted || !identical(previous, _community)) return;
      setState(() {
        _community = updated;
        _joined = updated.isJoined;
      });
    } catch (_) {
      // Keep the available profile if this background refresh is unavailable.
    }
  }

  bool _isGenericPostsCategory(CommunityCategory category) {
    final name = category.name.trim().toLowerCase();
    return name == 'posts' || name == 'publicaciones';
  }

  Widget _categoryFilters({
    double height = 48,
  }) => FutureBuilder<List<CommunityCategory>>(
    future: _categories,
    builder: (context, snapshot) {
      final categories = snapshot.data ?? const <CommunityCategory>[];
      final visibleCategories = _usesBusinessCategories
          ? categories
                .where((category) => !_isGenericPostsCategory(category))
                .toList(growable: false)
          : categories;
      if (_usesBusinessCategories && visibleCategories.isEmpty) {
        return const SizedBox.shrink();
      }
      return FeedFilterBar(
        height: height,
        labels: [
          context.tr('All'),
          for (final category in visibleCategories) context.tr(category.name),
        ],
        selectedIndex: _categoryId == null
            ? 0
            : visibleCategories.indexWhere((c) => c.id == _categoryId) + 1,
        onSelected: (index) => setState(
          () =>
              _categoryId = index == 0 ? null : visibleCategories[index - 1].id,
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
    _posts = _canViewPosts
        ? widget.repository.listPosts(
            _community.id,
            query: _searchController.text,
          )
        : Future.value(const <CommunityPost>[]);
    _members = _joined
        ? widget.repository.listMembers(_community.id)
        : Future.value(const <CommunityMember>[]);
  }

  Future<void> _openCommunitySurvey(
    CommunityHelpfulness feedback, {
    bool? initialHelpful,
  }) async {
    final current = feedback.myVote;
    var helpful = initialHelpful ?? current?.helpful ?? true;
    var locallyRelevant = current?.locallyRelevant ?? 'yes';
    var safeParticipation = current?.safeParticipation ?? 'yes';
    var wellOrganized = current?.wellOrganized ?? 'yes';
    var recommend = current?.recommend ?? true;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr(_spaceText('Community feedback'))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SurveyChoice<bool>(
                  question: _spaceText('Do you find this community helpful?'),
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
                  question: _spaceText('Is the community well organized?'),
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
                  question: _spaceText(
                    'Would you recommend this community to someone nearby?',
                  ),
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _togglePostSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchingPosts = !_searchingPosts;
      if (!_searchingPosts) {
        _searchController.clear();
        _reload();
      }
    });
  }

  void _searchPosts(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _categoryId = null;
        _posts = widget.repository.listPosts(_community.id, query: value);
      });
    });
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
          shortDescription: _community.shortDescription,
          description: _community.description,
          town: _community.town,
          visibility: _community.visibility,
          createdBy: _community.createdBy,
          createdAt: _community.createdAt,
          imageUrl: _community.imageUrl,
          coverImageUrl: _community.coverImageUrl,
          memberCount: nextMemberCount < 0 ? 0 : nextMemberCount,
          myRole: _joined ? CommunityRole.member : null,
          approvalRequired: _community.approvalRequired,
          showWeather: _community.showWeather,
          distanceKm: _community.distanceKm,
          rules: _community.rules,
          links: _community.links,
          type: _community.type,
          profileCategory: _community.profileCategory,
          slug: _community.slug,
          businessLocation: _community.businessLocation,
          businessServices: _community.businessServices,
          businessHours: _community.businessHours,
          businessFulfillmentOptions: _community.businessFulfillmentOptions,
          businessContact: _community.businessContact,
          published: _community.published,
          accentColor: _community.accentColor,
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
    if (_openingComposer || _savingMembership || !_canPublish) return;
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
      if (!_community.isPublicProfile) {
        final agreed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PostRulesReviewPage(
              community: _community,
              repository: widget.repository,
            ),
          ),
        );
        if (!mounted || agreed != true) return;
      }
      final post = await openPostComposer(
        context,
        community: _community,
        repository: widget.repository,
        categories: categories,
        initialCategory: categories
            .where((c) => c.id == _categoryId)
            .firstOrNull,
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
  Widget build(BuildContext context) {
    if (widget.screen == CommunityScreen.links) return _usefulLinksScreen();
    if (widget.screen == CommunityScreen.rules ||
        widget.screen == CommunityScreen.links ||
        widget.screen == CommunityScreen.rating) {
      final title = switch (widget.screen) {
        CommunityScreen.rules => _spaceText('Community rules'),
        CommunityScreen.links => 'Useful links',
        _ => _spaceText('Community rating'),
      };
      return Scaffold(
        appBar: AppBar(title: Text(context.tr(title))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            switch (widget.screen) {
              CommunityScreen.rules => _rulesContent(),
              CommunityScreen.links => _linksContent(),
              _ => _ratingContent(),
            },
          ],
        ),
      );
    }
    if (widget.screen == CommunityScreen.information) {
      return Scaffold(appBar: _navigationBar(), body: _aboutTab(context));
    }
    if (widget.screen == CommunityScreen.members) {
      return Scaffold(
        appBar: AppBar(
          title: _searchMembers
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.tr('Search members'),
                  ),
                  onChanged: (value) => setState(() => _memberQuery = value),
                )
              : Text(
                  context.tr(
                    _community.isPublicProfile ? 'Followers' : 'Members',
                  ),
                ),
          actions: [
            IconButton(
              tooltip: context.tr(
                _searchMembers ? 'Close search' : 'Search members',
              ),
              icon: Icon(
                _searchMembers ? WicchuIcons.x : WicchuIcons.magnifyingGlass,
              ),
              onPressed: () => setState(() {
                _searchMembers = !_searchMembers;
                _memberQuery = '';
              }),
            ),
          ],
        ),
        body: _membersTab(),
      );
    }
    return _feedScreen(context);
  }

  Widget _feedScreen(BuildContext context) => Scaffold(
    appBar: _navigationBar(),
    body: NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _buildHeader(context)),
        if (_joined && !_community.isPublicProfile)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              showCategories: false,
              builder: (context, collapse) =>
                  _categoryFilters(height: 48 - 4 * collapse),
            ),
          ),
      ],
      body: _postsTab(),
    ),
  );

  Future<void> _openInformation() async {
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          community: _community,
          repository: widget.repository,
          screen: CommunityScreen.information,
          onCommunityUpdated: (updated) {
            if (!mounted) return;
            setState(() {
              _community = updated;
              _joined = updated.isJoined;
            });
            widget.onCommunityUpdated?.call(updated);
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (result is Community) {
        _community = result;
        _joined = result.isJoined;
      }
      if (result is CommunityCategory) _categoryId = result.id;
      _reload();
    });
    await _refreshCommunity();
  }

  Future<void> _editPageCategories() async {
    if (_community.myRole != CommunityRole.owner &&
        _community.myRole != CommunityRole.admin) {
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryManagementPage(
          community: _community,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _openMembers({bool administration = false}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          community: _community,
          repository: widget.repository,
          screen: CommunityScreen.members,
          showAdministration: administration,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Widget _communityIdentity() => InkWell(
    key: const ValueKey('community-information-entry'),
    onTap: _openInformation,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _community.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(WicchuIcons.caretRight, size: 20),
        ],
      ),
    ),
  );

  Widget _memberCountLink({
    bool compact = false,
    bool typeFirst = false,
  }) => InkWell(
    key: const ValueKey('community-members-entry'),
    onTap: _openMembers,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: compact
          ? EdgeInsets.only(bottom: typeFirst ? 0 : 8)
          : const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _community.isPublicProfile
            ? typeFirst
                  ? '${context.tr(_community.spaceTypeLabel)} · ${context.trCount(_community.memberCount, singular: '{count} follower', plural: '{count} followers')}${_community.published ? '' : ' · ${context.tr('Unpublished')}'}'
                  : '${context.trCount(_community.memberCount, singular: '{count} follower', plural: '{count} followers')} · ${context.tr(_community.spaceTypeLabel)}${_community.published ? '' : ' · ${context.tr('Unpublished')}'}'
            : '${context.trCount(_community.memberCount, singular: '{count} member', plural: '{count} members')} · ${context.tr(_community.visibility == CommunityVisibility.public ? 'Public community' : 'Private community')}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );

  bool get _isLocalBusiness =>
      _community.isPublicProfile &&
      _community.profileCategory == ProfileCategory.localBusiness;

  AppBar _navigationBar() => AppBar(
    toolbarHeight: 52,
    leadingWidth: 44,
    titleSpacing: 8,
    centerTitle: false,
    backgroundColor: _pageHeaderColor(context),
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    automaticallyImplyLeading: false,
    leading: widget.embedded
        ? null
        : IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.pop(context, _community),
            icon: const Icon(WicchuIcons.arrowLeft),
          ),
    title: widget.screen == CommunityScreen.information
        ? null
        : _searchingPosts
        ? TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.tr('Search posts in {community}', {
                'community': _community.name,
              }),
              border: InputBorder.none,
            ),
            onChanged: _searchPosts,
            onSubmitted: (value) {
              _searchDebounce?.cancel();
              setState(() {
                _categoryId = null;
                _posts = widget.repository.listPosts(
                  _community.id,
                  query: value,
                );
              });
            },
          )
        : widget.onSwitchCommunity == null
        ? InkWell(
            onTap: widget.screen == CommunityScreen.feed
                ? _openInformation
                : null,
            child: Text(
              _community.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : InkWell(
            onTap: widget.onSwitchCommunity,
            borderRadius: BorderRadius.circular(12),
            child: Tooltip(
              message: context.tr(
                widget.onAccountMenu != null
                    ? 'Switch profile'
                    : 'Choose a community',
              ),
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
                  const Icon(WicchuIcons.caretDown),
                ],
              ),
            ),
          ),
    actions: [
      if (widget.onAccountMenu != null)
        IconButton(
          tooltip: context.tr('Account menu'),
          onPressed: widget.onAccountMenu,
          icon: const Icon(WicchuIcons.gearSix),
        ),
      if (_joined &&
          widget.screen == CommunityScreen.feed &&
          (!_isLocalBusiness || _searchingPosts))
        IconButton(
          tooltip: context.tr(
            _searchingPosts ? 'Close search' : 'Search posts',
          ),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(44),
            padding: EdgeInsets.zero,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: _togglePostSearch,
          icon: Icon(
            _searchingPosts ? WicchuIcons.x : WicchuIcons.magnifyingGlass,
            size: 20,
          ),
        ),
      if (!_community.isPublicProfile &&
          widget.screen == CommunityScreen.feed) ...[
        _communityHeaderActions(showMembership: false),
        const SizedBox(width: 8),
      ],
      if (_isLocalBusiness && widget.screen == CommunityScreen.feed) ...[
        _businessContactAction(),
        IconButton(
          key: const ValueKey('business-top-invite'),
          tooltip: context.tr('Invite'),
          onPressed: () => shareCommunity(context, _community),
          icon: const Icon(WicchuIcons.userPlus, size: 20),
        ),
        const SizedBox(width: 8),
      ],
      if (!_searchingPosts && widget.screen == CommunityScreen.information) ...[
        IconButton(
          key: const ValueKey('community-profile-menu'),
          tooltip: context.tr('More options'),
          icon: const Icon(WicchuIcons.dotsThree),
          onPressed: _showCommunityOptions,
        ),
      ],
    ],
  );

  Widget _communityHeaderActions({bool showMembership = true}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMembership && _joined && !_isLocalBusiness)
          _communityRoleBadge(),
        if (showMembership && _joined && _canInviteToCommunity)
          const SizedBox(width: 6),
        if (_canInviteToCommunity)
          IconButton(
            key: const ValueKey('community-header-invite'),
            tooltip: context.tr('Invite people'),
            onPressed: _inviteToCommunity,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(44),
              minimumSize: const Size.square(44),
              maximumSize: const Size.square(44),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              foregroundColor: scheme.onSurface,
            ),
            icon: const Icon(WicchuIcons.userPlus, size: 18),
          ),
        if (!_canManage &&
            (_community.isPublicProfile || _joined) &&
            !_community.isBanned)
          IconButton(
            key: const ValueKey('public-profile-message'),
            tooltip: context.tr(
              _community.isPublicProfile
                  ? 'Message on Wicchu'
                  : 'Message community admins',
            ),
            onPressed: _openSpaceChat,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(44),
              foregroundColor: scheme.onSurface,
              shape: const CircleBorder(),
            ),
            icon: const Icon(WicchuIcons.chatCircle, size: 19),
          ),
      ],
    );
  }

  Future<void> _showCommunityOptions() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        Widget option(
          String value,
          String label,
          IconData icon, {
          bool enabled = true,
          bool destructive = false,
        }) => ListTile(
          enabled: enabled,
          dense: true,
          minTileHeight: 52,
          leading: Icon(
            icon,
            color: enabled
                ? (destructive
                      ? Theme.of(sheetContext).colorScheme.error
                      : Theme.of(sheetContext).colorScheme.primary)
                : null,
          ),
          title: Text(
            context.tr(label),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: destructive
                  ? Theme.of(sheetContext).colorScheme.error
                  : null,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          onTap: enabled ? () => Navigator.pop(sheetContext, value) : null,
        );
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_community.isPublicProfile &&
                      widget.screen == CommunityScreen.feed)
                    option(
                      'information',
                      'Community information',
                      WicchuIcons.info,
                    ),
                  if (_isLocalBusiness) ...[
                    if (_joined && widget.screen == CommunityScreen.feed)
                      option(
                        'search',
                        'Search posts',
                        WicchuIcons.magnifyingGlass,
                      ),
                  ],
                  option('share', 'Share', WicchuIcons.export),
                  if (!_community.isPublicProfile ||
                      _community.links.isNotEmpty)
                    option('links', 'Useful links', WicchuIcons.linkSimple),
                  option('media', 'Media', WicchuIcons.images),
                  if (widget.screen == CommunityScreen.information &&
                      (_community.myRole == CommunityRole.owner ||
                          _community.myRole == CommunityRole.admin))
                    option(
                      'edit',
                      _community.isPublicProfile
                          ? (_isLocalBusiness
                                ? 'Edit business'
                                : 'Edit profile')
                          : 'Edit community',
                      WicchuIcons.pencilSimple,
                    ),
                  if (!_community.isPublicProfile &&
                      _joined &&
                      _community.myRole != CommunityRole.owner)
                    option(
                      'leave',
                      'Leave community',
                      WicchuIcons.signOut,
                      enabled: !_savingMembership,
                    ),
                  if (_community.myRole == CommunityRole.admin ||
                      _community.myRole == CommunityRole.moderator)
                    option(
                      'stepDown',
                      'Step down as administrator',
                      WicchuIcons.userMinus,
                    ),
                  if (_canManage)
                    option(
                      'contactSafety',
                      'Contact Wicchu Safety',
                      WicchuIcons.shieldPlus,
                    )
                  else ...[
                    const Divider(height: 17, indent: 16, endIndent: 16),
                    option(
                      'report',
                      _community.isPublicProfile
                          ? 'Report page'
                          : 'Report community',
                      WicchuIcons.flag,
                      destructive: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || value == null) return;
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
    } else if (value == 'information') {
      _openInformation();
    } else if (value == 'leave') {
      _confirmLeave();
    } else if (value == 'links') {
      _openInformationSection(CommunityScreen.links);
    } else if (value == 'search') {
      _togglePostSearch();
    } else if (value == 'share') {
      shareCommunity(context, _community);
    } else if (value == 'edit') {
      _editCommunity();
    } else if (value == 'report') {
      _reportCommunity();
    } else if (value == 'contactSafety') {
      _contactWicchuSafety();
    } else if (value == 'stepDown') {
      _stepDownAsAdministrator();
    }
  }

  Future<void> _reportCommunity() async {
    final report = await showContentReportDialog(
      context,
      title: _community.isPublicProfile ? 'Report page' : 'Report community',
    );
    if (report == null || !mounted) return;
    try {
      await widget.repository.reportCommunity(
        _community.id,
        report.$1,
        category: report.$2,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Report sent to Wicchu Safety'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _contactWicchuSafety() async {
    const issues = <String, String>{
      'account_compromised': 'Account or space may be compromised',
      'admin_abuse': 'Another administrator is abusing their role',
      'ownership_dispute': 'Ownership dispute',
      'impersonation': 'Impersonation',
      'illegal_dangerous': 'Illegal or dangerous activity',
      'cannot_remove_content': 'Content cannot be removed',
      'platform_restriction': 'Appeal a platform restriction',
      'other': 'Other safety concern',
    };
    var issue = 'other';
    var reason = '';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dialogContext.tr('Contact Wicchu Safety')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: issue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: dialogContext.tr('Safety issue'),
                  ),
                  items: issues.entries
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(
                            dialogContext.tr(item.value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setDialogState(() => issue = value ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  onChanged: (value) => reason = value,
                  decoration: InputDecoration(
                    hintText: dialogContext.tr(
                      'Explain what happened and what help you need',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (reason.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(dialogContext.tr('Send to Wicchu Safety')),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) return;
    try {
      await widget.repository.contactWicchuSafety(
        _community.id,
        reason.trim(),
        issue: issue,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Request sent to Wicchu Safety'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _stepDownAsAdministrator() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Step down as administrator?')),
        content: Text(
          dialogContext.tr(
            'You will become a regular member and lose access to management tools.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Step down')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.stepDownCommunityRole(_community.id);
      final updated = await widget.repository.getCommunity(_community.id);
      if (mounted) {
        setState(() {
          _community = updated;
          _joined = updated.isJoined;
          _reload();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('You are now a regular member.'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

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
        _joined = updated.isJoined;
        _reload();
      });
      widget.onCommunityUpdated?.call(updated);
    }
  }

  Widget _expandableCommunityImage(Widget child, String? url) {
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

  Widget _profileBadge(String label, {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: scheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            context.tr(label),
            style: TextStyle(
              color: scheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessServiceChip(BusinessService service) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            businessServiceIcon(service),
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            context.tr(service.label),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileEmptyState() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: .08),
                  ),
                ),
                Transform.rotate(
                  angle: -.12,
                  child: Container(
                    width: 60,
                    height: 70,
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Container(
                  width: 62,
                  height: 68,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    WicchuIcons.image,
                    size: 50,
                    color: theme.colorScheme.primary.withValues(alpha: .42),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(
                      WicchuIcons.plus,
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr(_canPublish ? 'Share your first post' : 'No posts yet'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              _canPublish
                  ? 'Keep your followers updated with news, photos and announcements.'
                  : 'Updates from this profile will appear here.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (_canPublish) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _openingComposer || _savingMembership
                  ? null
                  : _createPost,
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(WicchuIcons.plus),
              label: Text(context.tr('Create post')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerDetails() {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(height: 1.4);
    final description = _community.profileSummary;
    final location = [
      _community.town.name,
      _community.isPublicProfile
          ? _community.town.countryCode
          : _community.town.countryCode.toUpperCase() == 'EC'
          ? 'Ecuador'
          : _community.town.countryCode,
    ].where((part) => part.isNotEmpty).join(', ');
    final collapsedDescription = description
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.isNotEmpty)
        .join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_community.isPublicProfile)
          Text(
            '${context.tr(_community.spaceTypeLabel)} · $location',
            key: const ValueKey('page-header-location'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          _communityHeaderMetadata(location),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                text: TextSpan(text: collapsedDescription, style: style),
                maxLines: 2,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final overflows = painter.didExceedMaxLines;
              painter.dispose();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(
                    key: ValueKey(
                      'page-header-description-${_headerDescriptionExpanded ? 'expanded' : 'collapsed'}',
                    ),
                    child: Text(
                      _headerDescriptionExpanded
                          ? description
                          : collapsedDescription,
                      key: const ValueKey('page-header-description'),
                      style: style,
                      maxLines: _headerDescriptionExpanded ? null : 2,
                      overflow: _headerDescriptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  if (overflows)
                    TextButton(
                      key: const ValueKey('page-header-description-toggle'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => setState(
                        () => _headerDescriptionExpanded =
                            !_headerDescriptionExpanded,
                      ),
                      child: Text(
                        context.tr(
                          _headerDescriptionExpanded ? 'See less' : 'See more',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _communityHeaderMetadata(String location) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w400,
    );

    Widget item({
      required IconData icon,
      required String text,
      Key? textKey,
      VoidCallback? onTap,
    }) {
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 4),
          Text(text, key: textKey, style: textStyle),
        ],
      );
      if (onTap == null) return content;
      return InkWell(
        key: const ValueKey('community-header-members'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    Widget separator() => Text('·', style: textStyle);

    return Wrap(
      key: const ValueKey('community-header-metadata'),
      spacing: 7,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        item(
          icon: WicchuIcons.users,
          text: context.trCount(
            _community.memberCount,
            singular: '{count} member',
            plural: '{count} members',
          ),
          onTap: _openMembers,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            separator(),
            const SizedBox(width: 7),
            item(
              icon: _community.visibility == CommunityVisibility.public
                  ? WicchuIcons.globe
                  : WicchuIcons.lockKey,
              text: context.tr(
                _community.visibility == CommunityVisibility.public
                    ? 'Public'
                    : 'Private',
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            separator(),
            const SizedBox(width: 7),
            item(
              icon: WicchuIcons.mapPin,
              text: location,
              textKey: const ValueKey('page-header-location'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pageHeaderActions() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            TextButton.icon(
              key: const ValueKey('page-header-followers'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                padding: EdgeInsets.zero,
              ),
              onPressed: _openMembers,
              icon: const Icon(WicchuIcons.users, size: 18),
              label: Text(
                context.trCount(
                  _community.memberCount,
                  singular: _community.isPublicProfile
                      ? '{count} follower'
                      : '{count} member',
                  plural: _community.isPublicProfile
                      ? '{count} followers'
                      : '{count} members',
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (widget.screen == CommunityScreen.information &&
                    (_community.myRole == CommunityRole.owner ||
                        _community.myRole == CommunityRole.admin))
                  TextButton.icon(
                    key: const ValueKey('page-header-edit'),
                    onPressed: _editCommunity,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    icon: const Icon(WicchuIcons.camera, size: 18),
                    label: Text(context.tr('Edit')),
                  ),
                TextButton.icon(
                  key: const ValueKey('page-header-share'),
                  onPressed: () => shareCommunity(context, _community),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                  ),
                  icon: const Icon(WicchuIcons.export, size: 18),
                  label: Text(context.tr('Share')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _localBusinessHeaderDetails() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final metadataStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );
    final location = [
      _community.town.name,
      _community.town.countryCode.toUpperCase() == 'EC'
          ? 'Ecuador'
          : _community.town.countryCode,
    ].where((part) => part.isNotEmpty).join(', ');
    final summary = _community.profileSummary;
    final summaryLines = summary
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final summaryLead = summaryLines.isEmpty ? '' : summaryLines.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const ValueKey('local-business-metadata'),
          spacing: 7,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              key: const ValueKey('page-header-followers'),
              onTap: _openMembers,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      WicchuIcons.users,
                      size: 17,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.trCount(
                        _community.memberCount,
                        singular: '{count} follower',
                        plural: '{count} followers',
                      ),
                      style: metadataStyle,
                    ),
                  ],
                ),
              ),
            ),
            Text('·', style: metadataStyle),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  WicchuIcons.mapPin,
                  size: 17,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  key: const ValueKey('page-header-location'),
                  style: metadataStyle,
                ),
              ],
            ),
          ],
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            summaryLead,
            key: const ValueKey('page-header-description'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _localBusinessHeaderActions() {
    final canManage =
        _community.myRole == CommunityRole.owner ||
        _community.myRole == CommunityRole.admin;
    final isFollowing = !canManage && _joined;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!canManage && isFollowing)
          KeyedSubtree(
            key: const ValueKey('local-business-follow'),
            child: _communityRoleBadge(),
          ),
        if (!canManage && !isFollowing)
          FilledButton.icon(
            key: const ValueKey('local-business-follow'),
            onPressed: _savingMembership ? null : _toggleMembership,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(WicchuIcons.plus, size: 16),
            label: Text(
              context.tr('Follow'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _businessContactAction() {
    final colors = Theme.of(context).colorScheme;
    final canManage =
        _community.myRole == CommunityRole.owner ||
        _community.myRole == CommunityRole.admin;
    final hasContact =
        (!canManage && !_community.isBanned) ||
        _community.businessContact.phone.trim().isNotEmpty ||
        _community.businessContact.whatsapp.trim().isNotEmpty;
    return IconButton(
      key: const ValueKey('local-business-contact'),
      tooltip: context.tr('Contact'),
      onPressed: hasContact ? _contactBusiness : null,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        padding: EdgeInsets.zero,
        foregroundColor: colors.onSurface,
        shape: const CircleBorder(),
      ),
      icon: const Icon(WicchuIcons.chatCircle, size: 19),
    );
  }

  Future<void> _contactBusiness() async {
    final contact = _community.businessContact;
    final phone = contact.phone.trim();
    final whatsapp = contact.whatsapp.trim();
    if (phone.isEmpty && whatsapp.isEmpty) {
      await _openSpaceChat();
      return;
    }
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_canManage && !_community.isBanned)
              ListTile(
                leading: const Icon(WicchuIcons.chatCircle),
                title: Text(sheetContext.tr('Message')),
                onTap: () => Navigator.pop(sheetContext, 'message'),
              ),
            if (phone.isNotEmpty)
              ListTile(
                leading: const Icon(WicchuIcons.phone),
                title: Text(sheetContext.tr('Call')),
                onTap: () => Navigator.pop(sheetContext, 'phone'),
              ),
            if (whatsapp.isNotEmpty)
              ListTile(
                leading: const Icon(WicchuIcons.chatCircle),
                title: const Text('WhatsApp'),
                onTap: () => Navigator.pop(sheetContext, 'whatsapp'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (selection == 'message') {
      await _openSpaceChat();
      return;
    }
    await _openBusinessContact(
      selection == 'whatsapp' ? whatsapp : phone,
      whatsapp: selection == 'whatsapp',
    );
  }

  Color _pageHeaderColor(BuildContext context) {
    final theme = Theme.of(context);
    return Color.alphaBlend(
      profileAccentColor(
        _community.accentColor,
      ).withValues(alpha: theme.brightness == Brightness.dark ? .20 : .12),
      theme.colorScheme.surface,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final accent = profileAccentColor(_community.accentColor);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openInformation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            SizedBox(
              height: _community.coverImageUrl == null ? 76 : 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _expandableCommunityImage(
                    ColoredBox(
                      color: _pageHeaderColor(context),
                      child: _community.coverImageUrl == null
                          ? null
                          : WicchuNetworkImage(
                              url: _community.coverImageUrl!,
                              fit: BoxFit.cover,
                              decodeWidth: 1600,
                              errorBuilder: (_) => const SizedBox.shrink(),
                            ),
                    ),
                    _community.coverImageUrl,
                  ),
                  Positioned(
                    left: 16,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Semantics(
                        button: true,
                        label: context.tr(
                          _community.isPublicProfile
                              ? 'Profile information'
                              : 'Community information',
                        ),
                        child: GestureDetector(
                          onTap: _openInformation,
                          child: CommunityAvatar(
                            community: _community,
                            radius: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _communityIdentity()),
                            if (_isLocalBusiness) ...[
                              const SizedBox(width: 8),
                              _localBusinessHeaderActions(),
                            ] else if (_community.isPublicProfile) ...[
                              const SizedBox(width: 8),
                              _communityHeaderActions(),
                            ] else if (_joined) ...[
                              const SizedBox(width: 8),
                              _communityRoleBadge(),
                            ],
                          ],
                        ),
                        if (_isLocalBusiness)
                          _localBusinessHeaderDetails()
                        else
                          _headerDetails(),
                        if (!_isLocalBusiness && _community.isPublicProfile)
                          _pageHeaderActions(),
                        if (!_isLocalBusiness &&
                            !_joined &&
                            !_community.isBanned)
                          TextButton.icon(
                            onPressed: _savingMembership
                                ? null
                                : _toggleMembership,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(64, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: const StadiumBorder(),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .07),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            icon: _savingMembership
                                ? const SizedBox.square(
                                    dimension: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _joined
                                        ? WicchuIcons.check
                                        : WicchuIcons.plus,
                                    size: 16,
                                  ),
                            label: Text(
                              context.tr(
                                _community.isPublicProfile
                                    ? (_joined ? 'Following' : 'Follow')
                                    : (_joined ? 'Joined' : 'Join'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_community.isBanned) _banNotice(context),
          ],
        ),
      ),
    );
  }

  Widget _banNotice(BuildContext context) {
    final expiresAt = _community.banExpiresAt;
    final duration = expiresAt == null
        ? context.tr('This restriction is permanent unless it is reviewed.')
        : '${context.tr('Access returns on')} ${MaterialLocalizations.of(context).formatMediumDate(expiresAt.toLocal())}.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Your community access is restricted'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${context.tr('Reason')}: ${_community.banPublicReason ?? context.tr('Community rules violation.')}',
          ),
          const SizedBox(height: 4),
          Text(duration),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submittingBanAppeal ? null : _appealBan,
            icon: const Icon(WicchuIcons.gavel),
            label: Text(context.tr('Request Wicchu Safety review')),
          ),
        ],
      ),
    );
  }

  Future<void> _appealBan() async {
    var appealReason = '';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Request Wicchu Safety review')),
        content: TextField(
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          onChanged: (value) => appealReason = value,
          decoration: InputDecoration(
            labelText: dialogContext.tr('Why should this ban be reviewed?'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (appealReason.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(dialogContext.tr('Submit appeal')),
          ),
        ],
      ),
    );
    final reason = appealReason.trim();
    if (submitted != true || !mounted) return;
    setState(() => _submittingBanAppeal = true);
    try {
      await widget.repository.appealCommunityBan(_community.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Your appeal was sent to Wicchu Safety.')),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _submittingBanAppeal = false);
    }
  }

  Future<void> _refreshPosts() async {
    setState(_reload);
    try {
      await _posts;
    } catch (_) {}
  }

  Widget _composerEntry() {
    _composerProfile ??= widget.repository.getProfile();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey('community-composer-entry'),
          borderRadius: BorderRadius.circular(18),
          onTap: _openingComposer || _savingMembership ? null : _createPost,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FutureBuilder<WicchuProfile>(
                  future: _composerProfile,
                  builder: (context, snapshot) => UserAvatar(
                    name: snapshot.data?.name ?? '',
                    imageUrl: snapshot.data?.avatarUrl,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      context.tr('Write something…'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (_openingComposer)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _profileGrid = true;
  int _profileKind = 0;
  bool get _usesBusinessCategories =>
      _community.isPublicProfile &&
      _community.profileCategory == ProfileCategory.localBusiness;
  int get _activeProfileKind => _usesBusinessCategories ? 0 : _profileKind;

  Widget _postsTab() {
    if (!_canViewPosts) {
      return Center(
        child: Text(
          context.tr(
            _community.isBanned
                ? 'Community posts are unavailable while your access is restricted.'
                : 'Join to view community posts.',
          ),
        ),
      );
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
              if (!_joined)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            WicchuIcons.eye,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr(
                                _community.isPublicProfile
                                    ? 'Page preview. Follow to stay connected.'
                                    : 'Community preview. Join to take part.',
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_canPublish) SliverToBoxAdapter(child: _composerEntry()),
              if (_community.isPublicProfile)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (_usesBusinessCategories)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 12, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('Posts'),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              ProfileViewSwitch(
                                grid: _profileGrid,
                                onChanged: (value) =>
                                    setState(() => _profileGrid = value),
                              ),
                            ],
                          ),
                        )
                      else
                        FeedFilterBar(
                          labels: [
                            context.tr('Posts'),
                            context.tr('Media'),
                            context.tr('Polls'),
                          ],
                          selectedIndex: _profileKind,
                          onSelected: (value) =>
                              setState(() => _profileKind = value),
                        ),
                      if (_usesBusinessCategories)
                        KeyedSubtree(
                          key: const ValueKey('business-category-filters'),
                          child: _categoryFilters(height: 44),
                        )
                      else
                        Align(
                          alignment: Alignment.center,
                          child: ProfileViewSwitch(
                            grid: _profileGrid,
                            onChanged: (value) =>
                                setState(() => _profileGrid = value),
                          ),
                        ),
                    ],
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
                      .where(
                        (post) =>
                            !_community.isPublicProfile ||
                            _activeProfileKind == 0 ||
                            (_activeProfileKind == 1
                                ? post.media.isNotEmpty
                                : post.poll != null),
                      )
                      .toList();
                  if (posts.isEmpty &&
                      _searchController.text.trim().isNotEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                WicchuIcons.magnifyingGlassMinus,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('No posts found in {community}', {
                                  'community': _community.name,
                                }),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  if (posts.isEmpty &&
                      _community.isPublicProfile &&
                      _activeProfileKind != 0) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text(context.tr('No posts found'))),
                    );
                  }
                  if (posts.isEmpty &&
                      _community.isPublicProfile &&
                      _categoryId == null) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _profileEmptyState(),
                    );
                  }
                  if (posts.isEmpty && _categoryId != null) {
                    final category = categories
                        .where((c) => c.id == _categoryId)
                        .firstOrNull;
                    if (category != null) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CategoryEmptyState(
                            category: category.name,
                            onPublish:
                                !_canPublish ||
                                    _openingComposer ||
                                    _savingMembership
                                ? null
                                : _createPost,
                          ),
                        ),
                      );
                    }
                  }
                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(context.tr('No posts found')),
                      ),
                    );
                  }
                  if (_community.isPublicProfile && _profileGrid) {
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final category = categories
                              .where((c) => c.id == post.categoryId)
                              .firstOrNull;
                          return ProfilePostTile(
                            post: post,
                            categoryIcon: category?.icon ?? '💬',
                            onTap: () async {
                              if (post.media.isNotEmpty) {
                                await openCommunityPostMedia(
                                  context,
                                  widget.repository,
                                  post,
                                  initialIndex: post.media
                                      .indexWhere((m) => m.type == 'image')
                                      .clamp(0, post.media.length - 1),
                                  communityName: _community.name,
                                  category: category?.name ?? 'Post',
                                  categoryIcon: category?.icon ?? '💬',
                                );
                                if (mounted) {
                                  setState(() {
                                    _posts = widget.repository.listPosts(
                                      _community.id,
                                      query: _searchController.text,
                                    );
                                  });
                                }
                                return;
                              }
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostCollectionPage(
                                    profilePresentation: true,
                                    title: _community.name,
                                    repository: widget.repository,
                                    initialPostId: post.id,
                                    initialPosts: posts,
                                    categories: {
                                      for (final c in categories) c.id: c,
                                    },
                                    communityNames: {
                                      _community.id: _community.name,
                                    },
                                    loadPosts: () async {
                                      final refreshed = await widget.repository
                                          .listPosts(
                                            _community.id,
                                            query: _searchController.text,
                                          );
                                      return refreshed
                                          .where(
                                            (p) =>
                                                (_categoryId == null ||
                                                    p.categoryId ==
                                                        _categoryId) &&
                                                (_activeProfileKind == 0 ||
                                                    (_activeProfileKind == 1
                                                        ? p.media.isNotEmpty
                                                        : p.poll != null)),
                                          )
                                          .toList();
                                    },
                                  ),
                                ),
                              );
                              if (mounted) setState(_reload);
                            },
                          );
                        },
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
                            repository: widget.repository,
                            post: post,
                            key: ValueKey(post.id),
                            collapseText: true,
                            mediaFirst: _community.isPublicProfile,
                            compact: _community.isPublicProfile,
                            showCommunity: false,
                            onTap: () =>
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostCollectionPage(
                                      title: _community.name,
                                      profilePresentation:
                                          _community.isPublicProfile,
                                      initialPostId: post.id,
                                      initialPosts: posts,
                                      repository: widget.repository,
                                      loadPosts: () async {
                                        final refreshed = await widget
                                            .repository
                                            .listPosts(
                                              _community.id,
                                              query: _searchController.text,
                                            );
                                        return refreshed
                                            .where(
                                              (p) =>
                                                  (_categoryId == null ||
                                                      p.categoryId ==
                                                          _categoryId) &&
                                                  (!_community
                                                          .isPublicProfile ||
                                                      _activeProfileKind == 0 ||
                                                      (_activeProfileKind == 1
                                                          ? p.media.isNotEmpty
                                                          : p.poll != null)),
                                            )
                                            .toList();
                                      },
                                      categories: {
                                        for (final c in categories) c.id: c,
                                      },
                                      communityNames: {
                                        _community.id: _community.name,
                                      },
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
                            onReport: (reason, category, {hidePost}) =>
                                widget.repository.reportPost(
                                  post.id,
                                  reason,
                                  category: category,
                                  hidePost: hidePost == true,
                                ),
                            onShare: () => sharePost(
                              context,
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

  Widget _compactCommunityHeader() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _community.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: _isLocalBusiness ? 21 : null,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_joined)
                          _communityRoleBadge(inline: _isLocalBusiness),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _memberCountLink(
                      compact: true,
                      typeFirst: _isLocalBusiness,
                    ),
                    if (!_joined)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: const StadiumBorder(),
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: .07,
                          ),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        onPressed: _savingMembership ? null : _toggleMembership,
                        icon: _savingMembership
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(WicchuIcons.plus, size: 16),
                        label: Text(
                          context.tr(
                            _community.isPublicProfile ? 'Follow' : 'Join',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _expandableCommunityImage(
                CommunityAvatar(
                  community: _community,
                  radius: _isLocalBusiness ? 36 : 40,
                ),
                _community.imageUrl,
              ),
            ],
          ),
          if (_community.profileCategory == ProfileCategory.localBusiness &&
              _community.businessServices.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final service in _community.businessServices)
                  _businessServiceChip(service),
              ],
            ),
          ],
          if (_community.businessServices.contains(BusinessService.food)) ...[
            const SizedBox(height: 12),
            _restaurantSummary(),
          ],
          if (_community.isPublicProfile && !_canManage) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openSpaceChat,
                icon: const Icon(WicchuIcons.chatCircle),
                label: Text(context.tr('Message on Wicchu')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSpaceChat() async {
    try {
      final conversation = await widget.repository.startPageConversation(
        _community.id,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatPage(
            repository: widget.repository,
            conversation: conversation,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Widget _restaurantSummary() {
    final today = _todayBusinessHours();
    final isOpen = _isOpenNow(today);
    final contact = _community.businessContact;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(WicchuIcons.clock, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.tr(
                    today == null
                        ? 'Hours not provided'
                        : isOpen
                        ? 'Open now'
                        : 'Closed now',
                  ),
                  style: TextStyle(
                    color: isOpen
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (today != null) ...[
                  const Spacer(),
                  Text(
                    today.closed
                        ? context.tr('Closed today')
                        : '${today.open}–${today.close}',
                  ),
                ],
              ],
            ),
            if (_community.businessFulfillmentOptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final option in _community.businessFulfillmentOptions)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(context.tr(option.label)),
                    ),
                ],
              ),
            ],
            if (contact.phone.isNotEmpty || contact.whatsapp.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (contact.phone.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openBusinessContact(
                          contact.phone,
                          whatsapp: false,
                        ),
                        icon: const Icon(WicchuIcons.phone),
                        label: Text(context.tr('Call')),
                      ),
                    ),
                  if (contact.phone.isNotEmpty && contact.whatsapp.isNotEmpty)
                    const SizedBox(width: 8),
                  if (contact.whatsapp.isNotEmpty)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openBusinessContact(
                          contact.whatsapp,
                          whatsapp: true,
                        ),
                        icon: const Icon(WicchuIcons.chatCircle),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  BusinessHour? _todayBusinessHours() {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final day = days[DateTime.now().weekday - 1];
    return _community.businessHours
        .where((hours) => hours.day == day)
        .firstOrNull;
  }

  bool _isOpenNow(BusinessHour? hours) {
    if (hours == null || hours.closed) return false;
    int minutes(String value) {
      final parts = value.split(':');
      if (parts.length != 2) return -1;
      return (int.tryParse(parts[0]) ?? -24) * 60 +
          (int.tryParse(parts[1]) ?? -1);
    }

    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final open = minutes(hours.open);
    final close = minutes(hours.close);
    if (open < 0 || close < 0) return false;
    return close >= open
        ? current >= open && current < close
        : current >= open || current < close;
  }

  Future<void> _openBusinessContact(
    String value, {
    required bool whatsapp,
  }) async {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = whatsapp
        ? Uri.https('wa.me', '/${digits.replaceFirst('+', '')}')
        : Uri(scheme: 'tel', path: digits);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Unable to open link. Please try again.')),
        ),
      );
    }
  }

  Future<void> _showMembershipOptions(String message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        Widget option(
          String value,
          IconData icon,
          String label, {
          bool destructive = false,
        }) {
          final color = destructive ? colors.error : colors.primary;
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Material(
              color: color.withValues(alpha: .045),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: .1),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  sheetContext.tr(label),
                  style: TextStyle(
                    fontSize: 14,
                    color: destructive ? color : colors.onSurface,
                  ),
                ),
                trailing: Icon(WicchuIcons.caretRight, size: 20, color: color),
                onTap: () => Navigator.pop(sheetContext, value),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CommunityAvatar(community: _community, radius: 25),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _community.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        sheetContext,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(WicchuIcons.x),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_canManage)
                  option(
                    'manage',
                    WicchuIcons.shieldCheck,
                    _community.isPublicProfile
                        ? 'Manage profile'
                        : 'Manage community',
                  ),
                if (_community.myRole != CommunityRole.owner)
                  option(
                    'leave',
                    WicchuIcons.signOut,
                    _community.isPublicProfile ? 'Unfollow' : 'Leave community',
                    destructive: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == 'manage') _openManagement();
    if (action == 'leave') await _confirmLeave();
  }

  Widget _communityRoleBadge({bool expanded = false, bool inline = false}) {
    final scheme = Theme.of(context).colorScheme;
    final message = _community.isPublicProfile
        ? context.tr(switch (_community.myRole) {
            CommunityRole.owner => 'Owner',
            CommunityRole.admin => 'Admin',
            CommunityRole.moderator => 'Moderator',
            _ => 'Following',
          })
        : context.tr(switch (_community.myRole) {
            CommunityRole.owner => 'You own this community',
            CommunityRole.admin => 'You administer this community',
            CommunityRole.moderator => 'You moderate this community',
            _ => 'You are a member of this community',
          });
    return InkWell(
      key: const ValueKey('community-role-badge'),
      borderRadius: BorderRadius.circular(24),
      onTap: _savingMembership ? null : () => _showMembershipOptions(message),
      child: Semantics(
        button: true,
        label: message,
        child: inline
            ? SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  WicchuIcons.userCheck,
                  size: 20,
                  color: scheme.primary,
                ),
              )
            : expanded
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      WicchuIcons.userCheck,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr(
                        _community.isPublicProfile ? 'Following' : 'Joined',
                      ),
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      WicchuIcons.caretDown,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      WicchuIcons.userCheck,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _aboutWeather({
    bool compact = false,
  }) => FutureBuilder<CommunityWeather?>(
    future: _weather,
    builder: (context, snapshot) {
      final weather = snapshot.data;
      if (weather == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Material(
        color: compact
            ? Colors.transparent
            : theme.colorScheme.primary.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _weatherIcon(weather.weatherCode, weather.isDay),
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${weather.temperature.round()}°C · ${context.tr(weather.description)}',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(weather.townName),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('High {high}° · Low {low}°', {
                        'high': '${weather.maxTemperature.round()}',
                        'low': '${weather.minTemperature.round()}',
                      }),
                    ),
                    if (weather.observedAt != null)
                      Text(
                        context.tr('Updated {time}', {
                          'time': TimeOfDay.fromDateTime(
                            weather.observedAt!.toLocal(),
                          ).format(context),
                        }),
                      ),
                    Text(weather.provider, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          child: compact
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _weatherIcon(weather.weatherCode, weather.isDay),
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: DefaultTextStyle(
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          child: Wrap(
                            spacing: 4,
                            children: [
                              Text('${weather.temperature.round()}°C ·'),
                              Text(context.tr(weather.description)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _weatherIcon(weather.weatherCode, weather.isDay),
                        size: 26,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather.temperature.round()}°',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              context.tr(weather.description),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(WicchuIcons.caretRight, size: 18),
                    ],
                  ),
                ),
        ),
      );
    },
  );

  Widget _aboutMetadata() {
    final theme = Theme.of(context);
    Widget detail(IconData icon, String value, String label) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                context.tr(label),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 310 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 1
            : 3;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            SizedBox(
              width: width,
              child: detail(
                WicchuIcons.mapPin,
                _community.town.name,
                'Location',
              ),
            ),
            SizedBox(
              width: width,
              child: detail(
                WicchuIcons.globe,
                context.tr(
                  _community.isPublicProfile
                      ? _community.spaceTypeLabel
                      : _community.visibility == CommunityVisibility.public
                      ? 'Public'
                      : 'Private',
                ),
                _community.isPublicProfile ? 'Profile type' : 'Community type',
              ),
            ),
            SizedBox(
              width: width,
              child: detail(
                WicchuIcons.calendarBlank,
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(_community.createdAt.toLocal()),
                'Creation date',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _aboutTab(BuildContext context) => !_community.isPublicProfile
      ? _communityInformation()
      : ListView(
          key: const ValueKey('community-information-content'),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            if (widget.screen == CommunityScreen.information)
              _compactCommunityHeader(),
            if (_isLocalBusiness &&
                _community.shortDescription.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  _community.shortDescription.trim(),
                  key: const ValueKey('business-information-summary'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _Section(
              title: context.tr('About {name}', {'name': _community.name}),
              icon: WicchuIcons.article,
              trailing: _community.showWeather && _weather != null
                  ? _aboutWeather()
                  : null,
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
                  Divider(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .08),
                  ),
                  const SizedBox(height: 12),
                  _aboutMetadata(),
                ],
              ),
            ),
            if (_community.isPublicProfile &&
                (_community.myRole == CommunityRole.owner ||
                    _community.myRole == CommunityRole.admin))
              _informationRow(
                'Edit categories',
                WicchuIcons.shapes,
                context.tr('Add, rename or remove page categories.'),
                _editPageCategories,
                rowKey: const ValueKey('information-edit-categories'),
              ),
            FutureBuilder<CommunityHelpfulness>(
              future: _helpfulness,
              builder: (context, snapshot) {
                final feedback = snapshot.data;
                final summary = feedback == null
                    ? (snapshot.hasError
                          ? context.tr('Unable to load rating')
                          : context.tr('Loading…'))
                    : feedback.isPublic
                    ? context.tr(
                        _spaceText(
                          '{percentage}% of members find this community helpful',
                        ),
                        {'percentage': '${feedback.helpfulPercentage ?? 0}'},
                      )
                    : context.trCount(
                        (feedback.minimumResponses - feedback.responseCount)
                            .clamp(0, feedback.minimumResponses),
                        singular: _spaceText(
                          '{count} more response is needed to show the community score.',
                        ),
                        plural: _spaceText(
                          '{count} more responses are needed to show the community score.',
                        ),
                      );
                return _informationRow(
                  _spaceText('Community rating'),
                  WicchuIcons.starFill,
                  summary,
                  () => _openInformationSection(CommunityScreen.rating),
                  iconColor: Colors.amber.shade700,
                );
              },
            ),
            _informationRow(
              _community.isPublicProfile ? 'Followers' : 'Members',
              WicchuIcons.usersThree,
              context.trCount(
                _community.memberCount,
                singular: _community.isPublicProfile
                    ? '{count} follower'
                    : '{count} member',
                plural: _community.isPublicProfile
                    ? '{count} followers'
                    : '{count} members',
              ),
              _openMembers,
              count: _community.memberCount,
              rowKey: const ValueKey('information-members-entry'),
            ),
            FutureBuilder<CommunityRules>(
              future: _rules,
              builder: (context, snapshot) => _informationRow(
                _spaceText('Community rules'),
                WicchuIcons.shield,
                context.tr(
                  'Read the guidelines for a safe and respectful community.',
                ),
                () => _openInformationSection(CommunityScreen.rules),
                count: snapshot.hasData ? snapshot.data!.rules.length : null,
              ),
            ),
            _informationRow(
              'Useful links',
              WicchuIcons.linkSimple,
              context.tr('Website, directions and more'),
              () => _openInformationSection(CommunityScreen.links),
              count: _community.links.length + 2,
            ),
          ],
        );

  Future<void> _confirmLeave() async {
    if (_savingMembership || _community.myRole == CommunityRole.owner) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                WicchuIcons.signOut,
                color: Theme.of(sheetContext).colorScheme.error,
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                sheetContext.tr(
                  _community.isPublicProfile
                      ? 'Unfollow'
                      : 'Leave this community?',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _community.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(sheetContext).colorScheme.error,
                  foregroundColor: Theme.of(sheetContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(sheetContext, true),
                child: Text(
                  sheetContext.tr(
                    _community.isPublicProfile ? 'Unfollow' : 'Leave community',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(sheetContext.tr('Cancel')),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await _toggleMembership();
  }

  void _inviteToCommunity() {
    if (!_canInviteToCommunity) return;
    if (_canManage) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityInvitationsPage(
            community: _community,
            repository: widget.repository,
          ),
        ),
      );
    } else {
      shareCommunity(context, _community);
    }
  }

  Widget _communityInformation() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final location = '${_community.town.name}, ${_community.town.countryCode}';
    final canInvite = _canInviteToCommunity;
    Widget card(Widget child, {bool tinted = false}) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: tinted ? colors.primary.withValues(alpha: .05) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: tinted
            ? BorderSide.none
            : BorderSide(color: colors.onSurface.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    Widget stat(String value, String label, {VoidCallback? onTap, Key? key}) =>
        Expanded(
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    context.tr(label),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    Widget action(IconData icon, String label, VoidCallback? onTap) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.tr(label),
          onPressed: onTap,
          style: IconButton.styleFrom(
            foregroundColor: colors.onSurface,
            fixedSize: const Size(46, 46),
          ),
          icon: Icon(icon, size: 23),
        ),
        const SizedBox(height: 4),
        Text(context.tr(label), style: theme.textTheme.labelMedium),
      ],
    );
    Widget detail(
      IconData icon,
      String title,
      String? value, {
      VoidCallback? onTap,
      Widget? extra,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr(title),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (value != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  value,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (onTap != null)
                          Icon(
                            WicchuIcons.caretRight,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
                ?extra,
              ],
            ),
          ),
        ],
      ),
    );
    final divider = Divider(
      height: 1,
      indent: 62,
      endIndent: 16,
      color: colors.onSurface.withValues(alpha: .08),
    );
    return ListView(
      key: const ValueKey('community-information-content'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: _expandableCommunityImage(
                    CommunityAvatar(community: _community, radius: 28),
                    _community.imageUrl,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: Icon(
                      WicchuIcons.usersThree,
                      size: 15,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _community.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_joined)
              _communityRoleBadge(expanded: true)
            else
              TextButton.icon(
                onPressed: _savingMembership ? null : _toggleMembership,
                icon: const Icon(WicchuIcons.plus, size: 18),
                label: Text(context.tr('Join')),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            stat(
              '${_community.memberCount}',
              'Members',
              key: const ValueKey('information-members-entry'),
              onTap: _openMembers,
            ),
            if (_joined) ...[
              SizedBox(
                height: 24,
                child: VerticalDivider(color: colors.outlineVariant),
              ),
              FutureBuilder<List<CommunityPost>>(
                future: _posts,
                builder: (context, snapshot) => stat(
                  snapshot.hasData ? '${snapshot.data!.length}' : '—',
                  'Posts',
                  onTap: () => _openInformationSection(CommunityScreen.feed),
                ),
              ),
              SizedBox(
                height: 24,
                child: VerticalDivider(color: colors.outlineVariant),
              ),
              FutureBuilder<List<CommunityMember>>(
                future: _members,
                builder: (context, snapshot) => stat(
                  snapshot.hasData
                      ? '${snapshot.data!.where((m) => m.role != CommunityRole.member).length}'
                      : '—',
                  'Administration',
                  onTap: () => _openMembers(administration: true),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_community.profileSummary.isNotEmpty)
          card(
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final style = theme.textTheme.bodySmall!.copyWith(
                    height: 1.4,
                  );
                  final painter = TextPainter(
                    text: TextSpan(
                      text: _community.profileSummary,
                      style: style,
                    ),
                    maxLines: 2,
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: constraints.maxWidth);
                  final overflows = painter.didExceedMaxLines;
                  painter.dispose();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _community.profileSummary,
                        maxLines: _descriptionExpanded ? null : 2,
                        overflow: _descriptionExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: style,
                      ),
                      if (overflows)
                        TextButton(
                          key: const ValueKey('community-description-toggle'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => setState(
                            () => _descriptionExpanded = !_descriptionExpanded,
                          ),
                          child: Text(
                            context.tr(
                              _descriptionExpanded ? 'See less' : 'See more',
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 6),
                    ],
                  );
                },
              ),
            ),
            tinted: true,
          ),

        if (_community.description.trim().isNotEmpty)
          card(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('About {name}', {'name': _community.name}),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_community.description),
                ],
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.only(bottom: 18, top: 2),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 24,
            runSpacing: 12,
            children: [
              if (canInvite)
                action(WicchuIcons.userPlus, 'Invite', _inviteToCommunity),
              action(
                WicchuIcons.shareNetwork,
                'Share',
                () => shareCommunity(context, _community),
              ),
              if (_joined && _community.myRole != CommunityRole.owner)
                action(
                  WicchuIcons.signOut,
                  'Leave',
                  _savingMembership ? null : _confirmLeave,
                ),
            ],
          ),
        ),
        card(
          Column(
            children: [
              detail(
                WicchuIcons.mapPin,
                'Location',
                location,
                onTap: () => launchUrl(
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': location,
                  }),
                  mode: LaunchMode.externalApplication,
                ),
                extra: _community.showWeather && _weather != null
                    ? _aboutWeather(compact: true)
                    : null,
              ),
              divider,
              detail(
                WicchuIcons.usersThree,
                _community.visibility == CommunityVisibility.public
                    ? 'Public community'
                    : 'Private community',
                null,
              ),
              divider,
              detail(
                WicchuIcons.calendarBlank,
                context.tr('Created {date}', {
                  'date':
                      '${MaterialLocalizations.of(context).formatShortMonthDay(_community.createdAt.toLocal())} ${_community.createdAt.toLocal().year}',
                }),
                null,
              ),
            ],
          ),
        ),
        if (_joined)
          FutureBuilder<List<CommunityMember>>(
            future: _members,
            builder: (context, snapshot) {
              final admins =
                  snapshot.data
                      ?.where(
                        (m) =>
                            m.role == CommunityRole.owner ||
                            m.role == CommunityRole.admin,
                      )
                      .toList() ??
                  <CommunityMember>[];
              return card(
                ListTile(
                  key: const ValueKey('information-administration-entry'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  minTileHeight: 76,
                  leading: Icon(
                    WicchuIcons.shield,
                    color: colors.primary,
                    size: 28,
                  ),
                  title: Text(
                    context.tr('Administration'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: admins.isEmpty
                        ? Text(
                            context.tr(
                              snapshot.hasError
                                  ? 'Unable to load members'
                                  : snapshot.hasData
                                  ? 'No members found'
                                  : 'Loading…',
                            ),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final member in admins.take(3))
                                Tooltip(
                                  message: member.name,
                                  child: UserAvatar(
                                    name: member.name,
                                    imageUrl: member.avatarUrl,
                                    radius: 12,
                                  ),
                                ),
                              if (admins.length > 3)
                                CircleAvatar(
                                  radius: 12,
                                  child: Text(
                                    '+${admins.length - 3}',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                              Text(
                                context.trCount(
                                  admins.length,
                                  singular: '{count} administrator',
                                  plural: '{count} administrators',
                                ),
                              ),
                            ],
                          ),
                  ),
                  trailing: const Icon(WicchuIcons.caretRight, size: 20),
                  onTap: () => _openMembers(administration: true),
                ),
              );
            },
          ),
        FutureBuilder<CommunityRules>(
          future: _rules,
          builder: (context, snapshot) => _informationRow(
            'Community rules',
            WicchuIcons.article,
            context.trCount(
              (snapshot.data?.rules ?? _community.rules).length,
              singular: '{count} rule',
              plural: '{count} rules',
            ),
            () => _openInformationSection(CommunityScreen.rules),
          ),
        ),
        _informationRow(
          'Useful links',
          WicchuIcons.linkSimple,
          context.tr('Website, directions and more'),
          () => _openInformationSection(CommunityScreen.links),
          count: _community.links.length + 2,
        ),
        _informationRow(
          'Community rating',
          WicchuIcons.star,
          context.tr('Do you find this community helpful?'),
          () => _openInformationSection(CommunityScreen.rating),
        ),
        if (canInvite)
          card(
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(WicchuIcons.usersThree, color: colors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Help our community grow'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('Invite people from {town}', {
                            'town': _community.town.name,
                          }),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _inviteToCommunity,
                          icon: const Icon(WicchuIcons.userPlus, size: 18),
                          label: Text(context.tr('Invite')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            tinted: true,
          ),
      ],
    );
  }

  Future<void> _openInformationSection(CommunityScreen screen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          community: _community,
          repository: widget.repository,
          screen: screen,
        ),
      ),
    );
    if (!mounted) return;
    if (screen == CommunityScreen.links) {
      try {
        final updated = await widget.repository.getCommunity(_community.id);
        if (!mounted) return;
        setState(() => _community = updated);
      } catch (_) {
        // Keep the current information available if refresh fails.
      }
    }
    if (mounted) setState(_reload);
  }

  Widget _informationRow(
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onTap, {
    int? count,
    Color? iconColor,
    Key? rowKey,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: .07),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: rowKey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 76,
        leading: Icon(
          icon,
          size: 28,
          color: iconColor ?? theme.colorScheme.primary,
        ),
        title: Text(
          context.tr(title),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null) ...[
              Text('$count', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
            ],
            const Icon(WicchuIcons.caretRight),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _ratingContent() => _Section(
    title: context.tr(_spaceText('Community rating')),
    icon: WicchuIcons.starFill,
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
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 12),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            feedback.isPublic
                ? context.tr(
                    _spaceText(
                      '{percentage}% of members find this community helpful',
                    ),
                    {'percentage': '${feedback.helpfulPercentage ?? 0}'},
                  )
                : context.trCount(
                    (feedback.minimumResponses - feedback.responseCount).clamp(
                      0,
                      feedback.minimumResponses,
                    ),
                    singular: _spaceText(
                      '{count} more response is needed to show the community score.',
                    ),
                    plural: _spaceText(
                      '{count} more responses are needed to show the community score.',
                    ),
                  ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          children: [
            if (feedback.eligible) ...[
              const SizedBox(height: 14),
              if (feedback.myVote != null) ...[
                Row(
                  children: [
                    Icon(
                      WicchuIcons.checkCircleFill,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Your feedback is saved. You can update it at any time.',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Text(
                context.tr(_spaceText('Do you find this community helpful?')),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(WicchuIcons.thumbsUp),
                    label: Text(context.tr('Yes')),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(WicchuIcons.thumbsDown),
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
                          _openCommunitySurvey(
                            feedback,
                            initialHelpful: selection.first,
                          );
                        }
                      },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _savingHelpfulness
                    ? null
                    : () => _openCommunitySurvey(feedback),
                icon: const Icon(WicchuIcons.notePencil),
                label: Text(
                  context.tr(
                    feedback.myVote == null
                        ? 'Complete your rating'
                        : 'Update your rating',
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text(
                context.tr(
                  _community.myRole == CommunityRole.owner ||
                          _community.myRole == CommunityRole.admin
                      ? 'Owners and administrators cannot rate their own page.'
                      : _community.isPublicProfile
                          ? 'Follow this page to leave a rating.'
                          : 'Join this community to leave a rating.',
                ),
              ),
            ],
            if (feedback.insights.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                context.tr(_spaceText('Anonymous member insights')),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final entry in feedback.insights.entries)
                _DetailRow(
                  icon: WicchuIcons.chartLineUp,
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
  );

  bool get _canEditLinks =>
      _community.myRole == CommunityRole.owner ||
      _community.myRole == CommunityRole.admin;

  Future<void> _saveLinks(List<CommunityLink> links) async {
    if (_savingLinks) return;
    setState(() => _savingLinks = true);
    try {
      final current = await widget.repository.getCommunity(_community.id);
      final updated = await widget.repository.updateCommunity(
        current,
        town: current.town,
        name: current.name,
        description: current.description,
        visibility: current.visibility,
        approvalRequired: current.approvalRequired,
        showWeather: current.showWeather,
        links: links,
        profileCategory: current.profileCategory,
        businessServices: current.businessServices,
        businessLocation: current.businessLocation,
        imageUrl: current.imageUrl,
        coverImageUrl: current.coverImageUrl,
      );
      if (mounted) setState(() => _community = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingLinks = false);
    }
  }

  Future<void> _editUsefulLink({int? index}) async {
    final link = await Navigator.push<CommunityLink>(
      context,
      MaterialPageRoute(
        builder: (_) => OfficialLinkEditor(
          link: index == null ? null : _community.links[index],
        ),
      ),
    );
    if (!mounted || link == null) return;
    final links = [..._community.links];
    if (index == null) {
      links.add(link);
    } else {
      links[index] = link;
    }
    await _saveLinks(links);
  }

  Future<void> _openUsefulUrl(String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
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

  Widget _usefulLinksScreen() => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Useful links'),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      actions: [
        if (_canEditLinks)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .07),
              ),
              onPressed: _savingLinks || _community.links.length >= 10
                  ? null
                  : () => _editUsefulLink(),
              icon: const Icon(WicchuIcons.plus, size: 20),
              label: Text(context.tr('Add')),
            ),
          ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_savingLinks) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr(
                      _community.isPublicProfile
                          ? 'Official links and resources for this profile.'
                          : 'Official links and community resources.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                _linksContent(),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _usefulLinkRow({
    required String title,
    required String type,
    required String subtitle,
    required IconData icon,
    required String url,
    VoidCallback? onOpen,
    int? index,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final open = onOpen ?? () => _openUsefulUrl(url);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: colors.primary, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr(type)} · $subtitle',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Open link'),
                      onPressed: open,
                      icon: const Icon(WicchuIcons.arrowSquareOut, size: 20),
                    ),
                    if (_canEditLinks && index != null)
                      PopupMenuButton<String>(
                        tooltip: context.tr('More options'),
                        enabled: !_savingLinks,
                        icon: const Icon(
                          WicchuIcons.dotsThreeVertical,
                          size: 20,
                        ),
                        onSelected: (value) async {
                          if (value == 'copy') {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.tr('Website address copied.'),
                                  ),
                                ),
                              );
                            }
                          } else if (value == 'edit') {
                            _editUsefulLink(index: index);
                          } else if (value == 'remove') {
                            await _saveLinks(
                              [..._community.links]..removeAt(index),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'copy',
                            child: Text(context.tr('Copy link')),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(context.tr('Edit')),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(context.tr('Remove')),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          indent: 38,
          color: colors.onSurface.withValues(alpha: .08),
        ),
      ],
    );
  }

  Widget _linksContent() => Column(
    children: [
      _usefulLinkRow(
        title: _publicWebsiteUrl.replaceFirst('https://', ''),
        type: 'Website',
        subtitle: _community.name,
        icon: WicchuIcons.globe,
        url: _publicWebsiteUrl,
      ),
      for (final (index, link) in _community.links.indexed)
        _usefulLinkRow(
          index: index,
          title: link.label,
          url: link.url,
          subtitle: link.url.replaceFirst('https://', ''),
          type: switch (profileLinkNetwork(link.url)) {
            'telegram' => 'Telegram',
            'instagram' => 'Instagram',
            'facebook' => 'Facebook',
            'whatsapp' => 'WhatsApp',
            'youtube' => 'YouTube',
            _ => 'Website',
          },
          icon: switch (profileLinkNetwork(link.url)) {
            'telegram' => WicchuIcons.paperPlaneTilt,
            'instagram' => WicchuIcons.camera,
            'facebook' => WicchuIcons.facebookLogo,
            'whatsapp' => WicchuIcons.chatCircle,
            'youtube' => WicchuIcons.playCircle,
            _ => WicchuIcons.globe,
          },
        ),
      _usefulLinkRow(
        title: context.tr('Directions'),
        type: 'Map',
        subtitle:
            _community.businessLocation?.showExactAddress == true &&
                _community.businessLocation!.address.isNotEmpty
            ? _community.businessLocation!.address
            : _community.town.name,
        icon: WicchuIcons.mapTrifold,
        url: _directionsUri.toString(),
        onOpen: _openDirections,
      ),
    ],
  );

  Widget _rulesContent() => FutureBuilder<CommunityRules>(
    future: _rules,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _Section(
          title: context.tr(_spaceText('Community rules')),
          icon: WicchuIcons.shield,
          child: const LinearProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return _Section(
          title: context.tr(_spaceText('Community rules')),
          icon: WicchuIcons.shield,
          child: Text(context.trError(snapshot.error!)),
        );
      }
      final rules = snapshot.data?.rules ?? _community.rules;
      return _Section(
        title: context.tr(_spaceText('Community rules')),
        icon: WicchuIcons.shield,
        child: rules.isEmpty
            ? Text(
                context.tr(
                  _spaceText('No community rules have been added yet.'),
                ),
              )
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
  );

  Uri get _directionsUri {
    final location = _community.businessLocation;
    final destination = location?.hasCoordinates == true
        ? '${location!.latitude},${location.longitude}'
        : location?.address.isNotEmpty == true
        ? location!.address
        : '${_community.town.name}, ${_community.town.countryCode}';
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
  }

  Future<void> _openDirections() async {
    final uri = _directionsUri;
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
      return isDay ? WicchuIcons.sun : WicchuIcons.moon;
    }
    if (code <= 3) return WicchuIcons.cloud;
    if (code == 45 || code == 48) return WicchuIcons.cloudFog;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return WicchuIcons.drop;
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return WicchuIcons.snowflake;
    }
    if (code >= 95) return WicchuIcons.cloudLightning;
    return WicchuIcons.cloud;
  }

  Widget _membersTab() {
    if (!_joined) {
      return Center(
        child: Text(
          context.tr(
            _community.isPublicProfile
                ? 'Follow to view followers.'
                : 'Join to view community members.',
          ),
        ),
      );
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
        bool leader(CommunityMember member) =>
            member.role != CommunityRole.member;
        final leaders = members.where(leader).length;
        final visible = members
            .where(
              (member) =>
                  (_memberFilter == 0 ||
                      (_memberFilter == 1
                          ? leader(member)
                          : !leader(member))) &&
                  member.name.toLowerCase().contains(
                    _memberQuery.trim().toLowerCase(),
                  ),
            )
            .toList();
        return Column(
          children: [
            if (widget.screen == CommunityScreen.members)
              FeedFilterBar(
                labels: [
                  '${context.tr('All')} (${members.length})',
                  '${context.tr('Administration')} ($leaders)',
                  '${context.tr(_community.isPublicProfile ? 'Followers' : 'Members')} (${members.length - leaders})',
                ],
                selectedIndex: _memberFilter,
                onSelected: (index) => setState(() => _memberFilter = index),
              ),
            Expanded(
              child: visible.isEmpty
                  ? Center(child: Text(context.tr('No members found')))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final member = visible[index];
                        return ExploreResultCard(
                          margin: const EdgeInsets.only(bottom: 9),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 6,
                            ),
                            leading: Badge(
                              isLabelVisible: member.isOnline,
                              backgroundColor: Colors.green,
                              child: UserAvatar(
                                name: member.name,
                                imageUrl: member.avatarUrl,
                                radius: 23,
                              ),
                            ),
                            title: Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: member.isOnline
                                ? Text(
                                    context.tr('Online now'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  )
                                : null,
                            trailing: _profileBadge(switch (member.role) {
                              CommunityRole.owner => 'Owner',
                              CommunityRole.admin => 'Administrator',
                              CommunityRole.moderator => 'Moderator',
                              _ => 'Member',
                            }),
                            onTap: member.isAnonymous || member.userId.isEmpty
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MemberProfilePage(
                                        userId: member.userId,
                                        repository: widget.repository,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _mediaTab() {
    if (!_canViewPosts) {
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
            .expand(
              (post) => post.media.asMap().entries.map(
                (entry) => (post: post, index: entry.key, media: entry.value),
              ),
            )
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
            final entry = media[index];
            final item = entry.media;
            return InkWell(
              onTap: () => openCommunityPostMedia(
                context,
                widget.repository,
                entry.post,
                initialIndex: entry.index,
                communityName: _community.name,
              ),
              child: item.type == 'image'
                  ? WicchuNetworkImage(
                      url: item.previewUrl,
                      cacheKey: item.previewCacheKey,
                      fit: BoxFit.cover,
                      decodeWidth: 720,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: const Icon(WicchuIcons.playCircle, size: 40),
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
    this.trailing,
  });
  final Widget? trailing;
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
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
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
                );
                if (trailing == null) return heading;
                if (constraints.maxWidth >= 320 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.2) {
                  return Row(
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 8),
                      Flexible(child: trailing!),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 8), trailing!],
                );
              },
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
  const _TabHeaderDelegate({
    required this.builder,
    required this.showCategories,
  });

  final Widget Function(BuildContext, double) builder;
  final bool showCategories;

  @override
  double get minExtent => showCategories ? 84 : 44;
  @override
  double get maxExtent => showCategories ? 96 : 48;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapse = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: builder(context, collapse),
    );
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) =>
      oldDelegate.builder != builder ||
      oldDelegate.showCategories != showCategories;
}
