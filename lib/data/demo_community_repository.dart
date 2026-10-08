import '../domain/community_models.dart';
import '../domain/community_repository.dart';

class DemoCommunityRepository implements CommunityRepository {
  final List<BlockedUser> _blockedUsers = [];

  DemoCommunityRepository() {
    const town = Town(id: 'town-1', name: 'Town X', countryCode: 'EC');
    _communities.add(
      Community(
        id: 'town-x-community',
        name: 'Town X Community',
        description: 'Local community for Town X',
        town: town,
        visibility: CommunityVisibility.public,
        createdBy: 'current-user',
        createdAt: DateTime(2026),
        memberCount: 2481,
        myRole: CommunityRole.owner,
      ),
    );
    _categories['town-x-community'] = [
      for (final (index, name) in const [
        'News',
        'Marketplace',
        'Jobs',
        'Events',
        'Housing',
        'General',
        'Politics',
        'Local Businesses',
      ].indexed)
        CommunityCategory(
          id: 'category-$index',
          communityId: 'town-x-community',
          name: name,
          icon: _iconFor(name),
        ),
    ];
  }

  final List<Community> _communities = [];
  final Map<String, List<CommunityCategory>> _categories = {};
  final Map<String, List<CommunityRule>> _rules = {};
  final Map<String, int> _ruleVersions = {};
  final Map<String, List<CommunityPost>> _posts = {};
  final List<PromotionCampaign> _promotions = [];
  final Map<String, List<Comment>> _comments = {};
  final Set<String> _savedPostIds = {};
  final Map<String, CommunitySurveyResponse> _helpfulnessVotes = {};
  SocialLinks _socialLinks = const SocialLinks();
  EditableMemberProfile _editableProfile = const EditableMemberProfile(
    name: 'Michael P.',
    userName: 'michael',
  );
  NotificationPreferences _notificationPreferences =
      const NotificationPreferences();

  static const _towns = [Town(id: 'town-1', name: 'Town X', countryCode: 'EC')];

  String _profileName = 'Michael P.';
  String _profileUserName = 'michael';
  String _profileBio = '';
  String _profileLocation = '';

  @override
  Future<void> updateProfile({
    required String name,
    required String userName,
    required String bio,
    required String location,
  }) async {
    _profileName = name;
    _profileUserName = userName;
    _profileBio = bio;
    _profileLocation = location;
  }

  @override
  Future<WicchuProfile> getProfile() async => WicchuProfile(
    id: 'current-user',
    name: _profileName,
    userName: _profileUserName,
    location: _profileLocation,
    communityCount: 1,
    postCount: 0,
    savedPostCount: 0,
  );

  @override
  Future<PublicMemberProfile> getMemberProfile(String userId) async =>
      PublicMemberProfile(
        id: userId,
        name: userId == 'current-user' ? _profileName : 'Wicchu member',
        userName: userId == 'current-user' ? _profileUserName : '',
        bio: userId == 'current-user' ? _profileBio : null,
        location: userId == 'current-user' ? _profileLocation : null,
        postCount: (await listMemberPosts(userId)).length,
        communityCount: 1,
        socialLinks: _socialLinks,
        accentColor: _editableProfile.accentColor,
      );

  @override
  Future<PeopleSearchPage> searchPeople({
    String query = '',
    String? cursor,
    int limit = 25,
  }) async => const PeopleSearchPage(people: []);

  @override
  Future<SocialLinks> getMySocialLinks() async => _socialLinks;

  @override
  Future<SocialLinks> updateMySocialLinks(SocialLinks links) async =>
      _socialLinks = links;

  @override
  Future<EditableMemberProfile> getEditableProfile() async =>
      EditableMemberProfile(
        name: _editableProfile.name,
        userName: _editableProfile.userName,
        bio: _editableProfile.bio,
        location: _editableProfile.location,
        socialLinks: _socialLinks,
        accentColor: _editableProfile.accentColor,
      );

  @override
  Future<bool> isUsernameAvailable(String userName) async =>
      userName.toLowerCase() == _editableProfile.userName.toLowerCase() ||
      userName.toLowerCase() != 'taken';

  @override
  Future<EditableMemberProfile> updateEditableProfile(
    EditableMemberProfile profile,
  ) async {
    _editableProfile = profile;
    _socialLinks = profile.socialLinks;
    return profile;
  }

  @override
  Future<List<CommunityPost>> listMemberPosts(
    String userId, {
    String kind = 'all',
    String sort = 'newest',
  }) async {
    final posts = _posts.values.expand((items) => items).where((post) {
      if (post.authorId != userId) return false;
      if (kind == 'media') return post.media.isNotEmpty;
      if (kind == 'polls') return post.poll != null;
      return true;
    }).toList();
    posts.sort(
      (a, b) => sort == 'oldest'
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt),
    );
    return posts;
  }

  @override
  Future<NotificationFeed> listNotifications() async =>
      const NotificationFeed(items: [], unreadCount: 0);

  @override
  Future<void> markNotificationRead(String notificationId) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<NotificationPreferences> getNotificationPreferences() async =>
      _notificationPreferences;

  @override
  Future<NotificationPreferences> updateNotificationPreferences({
    bool? postActivity,
    bool? communityActivity,
    bool? promotions,
  }) async => _notificationPreferences = NotificationPreferences(
    postActivity: postActivity ?? _notificationPreferences.postActivity,
    communityActivity:
        communityActivity ?? _notificationPreferences.communityActivity,
    promotions: promotions ?? _notificationPreferences.promotions,
  );

  @override
  Future<void> registerDeviceToken(
    String token, {
    required String platform,
    String languageCode = 'en',
  }) async {}

  @override
  Future<void> unregisterDeviceToken(String token) async {}

  @override
  Future<List<Town>> listTowns() async => _towns;

  @override
  Future<Town> locateTown({
    required double latitude,
    required double longitude,
  }) async => _towns.first;

  @override
  Future<List<Community>> listManagedCommunities() async =>
      List.unmodifiable(_communities);

  @override
  Future<List<Community>> listCommunities({String? query}) async =>
      List.unmodifiable(
        _communities.where(
          (community) =>
              query == null ||
              query.trim().isEmpty ||
              community.name.toLowerCase().contains(
                query.trim().toLowerCase(),
              ) ||
              community.town.name.toLowerCase().contains(
                query.trim().toLowerCase(),
              ),
        ),
      );

  @override
  Future<Community> getCommunity(String communityId) async =>
      _communities.firstWhere((community) => community.id == communityId);

  @override
  Future<List<Community>> listJoinedCommunities() async =>
      List.unmodifiable(_communities);

  @override
  Future<List<Community>> listNearbyCommunities({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
  }) async => List.unmodifiable(_communities);

  @override
  Future<List<Community>> listLocalBusinesses({
    String? townId,
    String? query,
  }) async => List.unmodifiable(
    _communities.where(
      (community) =>
          community.profileCategory == ProfileCategory.localBusiness &&
          (townId == null || community.town.id == townId) &&
          (query == null ||
              query.trim().isEmpty ||
              community.name.toLowerCase().contains(query.toLowerCase())),
    ),
  );

  @override
  Future<List<Community>> listNearbyBusinesses({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? query,
  }) => listLocalBusinesses(query: query);

  @override
  Future<Community> createCommunity(CreateCommunityInput input) async {
    final id = 'community-${_communities.length + 1}';
    final community = Community(
      id: id,
      name: input.name,
      shortDescription: input.shortDescription,
      description: input.description,
      town: input.town,
      visibility: input.visibility,
      createdBy: 'current-user',
      createdAt: DateTime.now(),
      memberCount: 1,
      myRole: CommunityRole.owner,
      approvalRequired: input.approvalRequired,
      rules: input.rules,
      type: input.type,
      profileCategory: input.type == CommunityType.publicProfile
          ? input.profileCategory
          : null,
    );
    _communities.add(community);
    _categories[id] = [
      for (final (index, name) in input.categoryNames.indexed)
        CommunityCategory(
          id: 'category-$index',
          communityId: id,
          name: name,
          icon: _iconFor(name),
        ),
    ];
    _rules[id] = [
      for (final (index, rule) in input.rules.indexed)
        CommunityRule(
          id: 'rule-$index',
          title: rule.title,
          description: rule.description,
          position: index,
        ),
    ];
    _ruleVersions[id] = input.rules.isEmpty ? 0 : 1;
    return community;
  }

  @override
  Future<PostMedia> uploadPostMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => PostMedia(
    url: filename,
    type: mimeType.startsWith('video/') ? 'video' : 'image',
    blobName: filename,
  );

  @override
  Future<void> joinCommunity(String communityId) async {}

  @override
  Future<CommunityHelpfulness> getCommunityHelpfulness(
    String communityId,
  ) async => CommunityHelpfulness(
    responseCount: _helpfulnessVotes.containsKey(communityId) ? 1 : 0,
    minimumResponses: 10,
    isPublic: false,
    eligible: true,
    myVote: _helpfulnessVotes[communityId],
  );

  @override
  Future<CommunityHelpfulness> setCommunityHelpfulness(
    String communityId, {
    required bool helpful,
    String? locallyRelevant,
    String? safeParticipation,
    String? wellOrganized,
    bool? recommend,
  }) async {
    _helpfulnessVotes[communityId] = CommunitySurveyResponse(
      helpful: helpful,
      locallyRelevant: locallyRelevant,
      safeParticipation: safeParticipation,
      wellOrganized: wellOrganized,
      recommend: recommend,
    );
    return getCommunityHelpfulness(communityId);
  }

  @override
  Future<CommunityInvitation> createCommunityInvitation(
    String communityId,
    String email,
  ) async => CommunityInvitation(
    id: 'invite-${DateTime.now().millisecondsSinceEpoch}',
    communityId: communityId,
    email: email,
    status: 'pending',
    expiresAt: DateTime.now().add(const Duration(days: 14)),
    createdAt: DateTime.now(),
    invitationUrl: 'https://hexora.dev/wicchu/invitations/demo',
  );

  @override
  Future<CommunityInvitation> createCommunityInvitationLink(
    String communityId,
  ) async => CommunityInvitation(
    id: 'link-${DateTime.now().millisecondsSinceEpoch}',
    communityId: communityId,
    type: 'link',
    status: 'pending',
    expiresAt: DateTime.now().add(const Duration(days: 14)),
    createdAt: DateTime.now(),
    invitationUrl: 'https://hexora.dev/wicchu/invitations/demo-token',
  );

  @override
  Future<CommunityInvitation> getCommunityInvitationLink(String token) async =>
      CommunityInvitation(
        id: 'link-demo',
        communityId: 'community-1',
        type: 'link',
        status: 'pending',
        expiresAt: DateTime.now().add(const Duration(days: 14)),
        createdAt: DateTime.now(),
        communityName: 'Wicchu community',
      );

  @override
  Future<void> respondToCommunityInvitationLink(
    String token, {
    required bool accept,
  }) async {}

  @override
  Future<List<CommunityInvitation>> listCommunityInvitations(
    String communityId,
  ) async => const [];

  @override
  Future<List<CommunityInvitation>> listMyCommunityInvitations() async =>
      const [];

  @override
  Future<void> respondToCommunityInvitation(
    String invitationId, {
    required bool accept,
  }) async {}

  @override
  Future<void> revokeCommunityInvitation(
    String communityId,
    String invitationId,
  ) async {}

  @override
  Future<void> createOwnershipTransfer(
    String communityId,
    String targetUserId,
  ) async {}

  @override
  Future<void> stepDownCommunityRole(String communityId) async {}

  @override
  Future<void> leaveCommunity(String communityId) async {}

  @override
  Future<bool> getAdminAnonymity(String communityId) async => false;

  @override
  Future<bool> updateAdminAnonymity(
    String communityId, {
    required bool anonymousInCommunity,
  }) async => anonymousInCommunity;

  @override
  Future<CommunityRules> listRules(String communityId) async => CommunityRules(
    rules: List.unmodifiable(_rules[communityId] ?? const []),
    rulesVersion: _ruleVersions[communityId] ?? 0,
    acceptedRulesVersion: _ruleVersions[communityId] ?? 0,
    acceptanceRequired: false,
    canManage: true,
  );

  @override
  Future<CommunityRule> createRule(
    String communityId, {
    required String title,
    required String description,
    required int position,
  }) async {
    final rule = CommunityRule(
      id: 'rule-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: description,
      position: position,
    );
    _rules.putIfAbsent(communityId, () => []).add(rule);
    _ruleVersions[communityId] = (_ruleVersions[communityId] ?? 0) + 1;
    return rule;
  }

  @override
  Future<CommunityRule> updateRule(
    String communityId,
    CommunityRule rule, {
    String? title,
    String? description,
    int? position,
  }) async {
    final updated = CommunityRule(
      id: rule.id,
      title: title ?? rule.title,
      description: description ?? rule.description,
      position: position ?? rule.position,
    );
    final rules = _rules[communityId] ?? [];
    final index = rules.indexWhere((item) => item.id == rule.id);
    if (index >= 0) rules[index] = updated;
    _ruleVersions[communityId] = (_ruleVersions[communityId] ?? 0) + 1;
    return updated;
  }

  @override
  Future<void> deleteRule(String communityId, String ruleId) async {
    _rules[communityId]?.removeWhere((rule) => rule.id == ruleId);
    _ruleVersions[communityId] = (_ruleVersions[communityId] ?? 0) + 1;
  }

  @override
  Future<void> acceptRules(String communityId, int rulesVersion) async {}

  @override
  Future<List<CommunityCategory>> listCategories(String communityId) async =>
      List.unmodifiable(_categories[communityId] ?? const []);

  @override
  Future<CommunityCategory> createCategory(
    String communityId, {
    required String name,
    String description = '',
    String? icon,
  }) async {
    final category = CommunityCategory(
      id: 'category-${DateTime.now().microsecondsSinceEpoch}',
      communityId: communityId,
      name: name,
      description: description,
      icon: icon ?? _iconFor(name),
    );
    _categories.putIfAbsent(communityId, () => []).add(category);
    return category;
  }

  @override
  Future<CommunityCategory> updateCategory(
    String communityId,
    CommunityCategory category, {
    required String name,
    required String description,
    String? icon,
  }) async {
    final updated = CommunityCategory(
      id: category.id,
      communityId: communityId,
      name: name,
      description: description,
      icon: icon ?? category.icon,
      rules: category.rules,
    );
    final items = _categories[communityId] ?? [];
    final index = items.indexWhere((item) => item.id == category.id);
    if (index >= 0) items[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteCategory(String communityId, String categoryId) async {
    _categories[communityId]?.removeWhere((item) => item.id == categoryId);
  }

  @override
  Future<List<CommunityMember>> listMembers(
    String communityId, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'current-user',
      communityId: communityId,
      name: 'You',
      role: CommunityRole.owner,
      status: MembershipStatus.active,
      joinedAt: DateTime(2026),
    ),
  ];

  @override
  Future<void> setMemberRole(
    String communityId,
    String userId,
    CommunityRole role,
  ) async {}

  @override
  Future<void> setPageInboxAccess(
    String communityId,
    String userId, {
    required bool enabled,
  }) async {}

  @override
  Future<void> setMemberAccess(
    String communityId,
    String userId, {
    required String action,
    String? reason,
    String? internalNote,
    DateTime? expiresAt,
  }) async {}

  @override
  Future<Community> updateCommunity(
    Community community, {
    required Town town,
    required String name,
    String? shortDescription,
    required String description,
    required CommunityVisibility visibility,
    required bool approvalRequired,
    required bool showWeather,
    required List<CommunityLink> links,
    ProfileCategory? profileCategory,
    required List<BusinessService> businessServices,
    required BusinessLocation? businessLocation,
    List<BusinessHour>? businessHours,
    List<BusinessFulfillmentOption>? businessFulfillmentOptions,
    BusinessContact? businessContact,
    String? imageUrl,
    String? imageBlobName,
    String? coverImageUrl,
    String? coverImageBlobName,
    bool? published,
    String? accentColor,
  }) async {
    final updated = Community(
      id: community.id,
      name: name,
      shortDescription: shortDescription ?? community.shortDescription,
      description: description,
      town: town,
      visibility: visibility,
      createdBy: community.createdBy,
      createdAt: community.createdAt,
      imageUrl: imageBlobName == null ? community.imageUrl : imageUrl,
      coverImageUrl: coverImageBlobName == null
          ? community.coverImageUrl
          : coverImageUrl,
      memberCount: community.memberCount,
      myRole: community.myRole,
      approvalRequired: approvalRequired,
      showWeather: showWeather,
      distanceKm: community.distanceKm,
      rules: community.rules,
      links: List.unmodifiable(links),
      type: community.type,
      profileCategory: profileCategory ?? community.profileCategory,
      businessServices: List.unmodifiable(businessServices),
      businessLocation: businessLocation,
      businessHours: businessHours ?? community.businessHours,
      businessFulfillmentOptions:
          businessFulfillmentOptions ?? community.businessFulfillmentOptions,
      businessContact: businessContact ?? community.businessContact,
      published: published ?? community.published,
      accentColor: accentColor ?? community.accentColor,
    );
    final index = _communities.indexWhere((item) => item.id == community.id);
    if (index >= 0) _communities[index] = updated;
    return updated;
  }

  @override
  Future<CommunityWeather?> getCommunityWeather(String communityId) async =>
      CommunityWeather(
        townName: 'Echeandía',
        temperature: 27,
        apparentTemperature: 29,
        minTemperature: 21,
        maxTemperature: 30,
        weatherCode: 2,
        description: 'Partly cloudy',
        isDay: true,
        observedAt: DateTime.now(),
        provider: 'Open-Meteo',
      );

  @override
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  }) async {
    final posts = (_posts[communityId] ?? const <CommunityPost>[])
        .where(
          (post) =>
              (categoryId == null || post.categoryId == categoryId) &&
              (query == null ||
                  post.text.toLowerCase().contains(query.toLowerCase())),
        )
        .toList();
    if (sort == 'popular') {
      posts.sort((a, b) => b.reactionCount.compareTo(a.reactionCount));
    }
    return List.unmodifiable(posts);
  }

  @override
  Future<List<CommunityPost>> listFollowingPosts({String? query}) async =>
      List.unmodifiable(
        _posts.values
            .expand((posts) => posts)
            .where(
              (post) =>
                  query == null ||
                  post.text.toLowerCase().contains(query.toLowerCase()),
            ),
      );

  @override
  Future<List<CommunityPost>> listTodayMenus(
    String townId, {
    String? query,
  }) async => _posts.values
      .expand((posts) => posts)
      .where((post) {
        final community = _communities.firstWhere(
          (item) => item.id == post.communityId,
        );
        return community.town.id == townId &&
            post.todayMenu != null &&
            !post.todayMenu!.isExpired &&
            (query == null ||
                post.text.toLowerCase().contains(query.toLowerCase()));
      })
      .toList(growable: false);

  @override
  Future<List<CommunityPost>> listLocalBusinessPosts(
    String townId, {
    String? query,
  }) async => _posts.values
      .expand((posts) => posts)
      .where((post) {
        final community = _communities.firstWhere(
          (item) => item.id == post.communityId,
        );
        final active = post.todayMenu == null || !post.todayMenu!.isExpired;
        return community.town.id == townId &&
            (post.todayMenu != null || post.businessFeature != null) &&
            active &&
            (query == null ||
                post.text.toLowerCase().contains(query.toLowerCase()));
      })
      .toList(growable: false);

  @override
  Future<List<CommunityPost>> listBusinessPosts(
    List<String> businessIds, {
    String? query,
  }) async => _posts.values
      .expand((posts) => posts)
      .where(
        (post) =>
            businessIds.contains(post.communityId) &&
            (post.todayMenu != null || post.businessFeature != null) &&
            (query == null ||
                query.trim().isEmpty ||
                post.text.toLowerCase().contains(query.toLowerCase())),
      )
      .toList(growable: false);

  @override
  Future<CommunityPost> getPost(String postId) async => _posts.values
      .expand((posts) => posts)
      .firstWhere((post) => post.id == postId);

  @override
  Future<SharedPostPreview> getSharedPost(String postId) async {
    final post = await getPost(postId);
    final community = _communities.firstWhere(
      (item) => item.id == post.communityId,
    );
    final category = (_categories[community.id] ?? const []).firstWhere(
      (item) => item.id == post.categoryId,
    );
    return SharedPostPreview(
      post: post,
      communityId: community.id,
      communityName: community.name,
      communityDescription: community.description,
      communityImageUrl: community.imageUrl,
      categoryName: category.name,
      categoryIcon: category.icon,
    );
  }

  @override
  Future<PostShareKit> getPostShareKit(String postId) async {
    final post = await getPost(postId);
    final canonical = 'https://wicchu.com/posts/$postId';
    final message = '${post.text}\n\n$canonical';
    return PostShareKit(
      canonicalUrl: canonical,
      message: message,
      whatsappUrl: 'https://wa.me/?text=${Uri.encodeQueryComponent(message)}',
      facebookUrl:
          'https://www.facebook.com/sharer/sharer.php?u='
          '${Uri.encodeQueryComponent(canonical)}',
      instagramFeedImageUrl: '$canonical/card/feed.png',
      instagramStoryImageUrl: '$canonical/card/story.png',
    );
  }

  @override
  Future<void> recordPostShare(String postId) async {}

  @override
  Future<void> recordBusinessPostEngagement(
    String postId, {
    required String action,
  }) async {}

  @override
  Future<CommunityPost> createPost(
    String communityId,
    CreatePostInput input,
  ) async {
    final post = CommunityPost(
      id: 'post-${DateTime.now().microsecondsSinceEpoch}',
      communityId: communityId,
      categoryId: input.categoryId,
      authorId: 'current-user',
      authorName: input.anonymousAsAdmin
          ? 'Community Admin'
          : input.anonymousAsMember
          ? 'Anonymous Member'
          : 'You',
      isAnonymous: input.anonymousAsAdmin || input.anonymousAsMember,
      text: input.text,
      status: input.anonymousAsMember
          ? PostStatus.pendingApproval
          : PostStatus.published,
      createdAt: DateTime.now(),
      media: input.media,
      poll: input.pollOptions.isEmpty
          ? null
          : PostPoll(
              options: [
                for (final (index, text) in input.pollOptions.indexed)
                  PollOption(
                    id: 'poll-option-$index',
                    text: text,
                    voteCount: 0,
                  ),
              ],
            ),
      todayMenu: input.todayMenu,
      businessFeature: input.businessFeature,
    );
    _posts.putIfAbsent(communityId, () => []).insert(0, post);
    return post;
  }

  @override
  Future<CommunityPost> updatePost(String postId, CreatePostInput input) async {
    for (final entry in _posts.entries) {
      final index = entry.value.indexWhere((post) => post.id == postId);
      if (index < 0) continue;
      final current = entry.value[index];
      final updated = CommunityPost(
        id: current.id,
        communityId: current.communityId,
        categoryId: input.categoryId,
        authorId: current.authorId,
        authorName: input.anonymousAsAdmin
            ? 'Community Admin'
            : input.anonymousAsMember
            ? 'Anonymous Member'
            : 'You',
        authorAvatarUrl: input.anonymousAsAdmin || input.anonymousAsMember
            ? null
            : current.authorAvatarUrl,
        isAnonymous: input.anonymousAsAdmin || input.anonymousAsMember,
        text: input.text,
        status: input.anonymousAsMember
            ? PostStatus.pendingApproval
            : current.status,
        createdAt: current.createdAt,
        editedAt: DateTime.now(),
        ownedByMe: true,
        media: input.media,
        reactionCount: current.reactionCount,
        commentCount: current.commentCount,
        reactedByMe: current.reactedByMe,
        savedByMe: current.savedByMe,
        poll: input.pollOptions.isEmpty
            ? null
            : PostPoll(
                options: [
                  for (final (optionIndex, text) in input.pollOptions.indexed)
                    PollOption(
                      id: 'poll-option-$optionIndex',
                      text: text,
                      voteCount: 0,
                    ),
                ],
              ),
        todayMenu: input.todayMenu ?? current.todayMenu,
        businessFeature: input.businessFeature ?? current.businessFeature,
        businessViewCount: current.businessViewCount,
        businessContactCount: current.businessContactCount,
      );
      entry.value[index] = updated;
      return updated;
    }
    throw StateError('Post not found');
  }

  @override
  Future<void> deletePost(String postId) async {
    for (final posts in _posts.values) {
      posts.removeWhere((post) => post.id == postId);
    }
  }

  @override
  Future<int> setPostReaction(String postId, {required bool reacted}) async =>
      reacted ? 1 : 0;

  @override
  Future<PostPoll> voteOnPost(String postId, String optionId) async {
    final post = await getPost(postId);
    return post.poll ?? const PostPoll(options: []);
  }

  @override
  Future<List<Comment>> listComments(String postId) async =>
      List.unmodifiable(_comments[postId] ?? const []);

  @override
  Future<Comment> createComment(
    String postId,
    String text, {
    String? parentCommentId,
  }) async {
    final comment = Comment(
      id: 'comment-${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      authorId: 'current-user',
      authorName: 'You',
      text: text,
      createdAt: DateTime.now(),
      parentCommentId: parentCommentId,
    );
    _comments.putIfAbsent(postId, () => []).add(comment);
    return comment;
  }

  @override
  Future<int> setCommentReaction(
    String commentId, {
    required bool reacted,
  }) async {
    for (final entry in _comments.entries) {
      final index = entry.value.indexWhere(
        (comment) => comment.id == commentId,
      );
      if (index < 0) continue;
      final current = entry.value[index];
      entry.value[index] = Comment(
        id: current.id,
        postId: current.postId,
        authorId: current.authorId,
        text: current.text,
        createdAt: current.createdAt,
        authorName: current.authorName,
        authorAvatarUrl: current.authorAvatarUrl,
        parentCommentId: current.parentCommentId,
        reactionCount: reacted
            ? current.reactionCount + (current.reactedByMe ? 0 : 1)
            : current.reactionCount - (current.reactedByMe ? 1 : 0),
        reactedByMe: reacted,
      );
      return entry.value[index].reactionCount;
    }
    return 0;
  }

  @override
  Future<List<CommunityPost>> listMyPosts() async => List.unmodifiable(
    _posts.values
        .expand((posts) => posts)
        .where((post) => post.authorId == 'current-user'),
  );

  @override
  Future<List<CommunityPost>> listSavedPosts() async => List.unmodifiable(
    _posts.values
        .expand((posts) => posts)
        .where((post) => _savedPostIds.contains(post.id)),
  );

  @override
  Future<void> setPostSaved(String postId, {required bool saved}) async {
    saved ? _savedPostIds.add(postId) : _savedPostIds.remove(postId);
  }

  @override
  Future<void> reportPost(
    String postId,
    String reason, {
    String category = 'other',
    bool hidePost = false,
  }) async {}

  @override
  Future<void> reportComment(
    String commentId,
    String reason, {
    String category = 'other',
  }) async {}

  @override
  Future<void> reportMember(
    String userId,
    String reason, {
    String category = 'other',
  }) async {}

  @override
  Future<void> reportCommunity(
    String communityId,
    String reason, {
    String category = 'other',
  }) async {}

  @override
  Future<void> appealCommunityBan(String communityId, String reason) async {}

  @override
  Future<void> contactWicchuSafety(
    String communityId,
    String reason, {
    required String issue,
  }) async {}

  @override
  Future<List<PlatformReport>> listPlatformReports({
    bool resolved = false,
  }) async => [];

  @override
  Future<void> decidePlatformReport(
    String reportId, {
    required String action,
    String? note,
  }) async {}

  @override
  Future<AdminAttentionSummary> getAdminAttention(String communityId) async =>
      const AdminAttentionSummary();

  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      const CommunityInsights();

  @override
  Future<List<CommunityReport>> listReports(String communityId) async => [];

  @override
  Future<void> decideReport(
    String communityId,
    String reportId, {
    required bool resolve,
  }) async {}

  @override
  Future<List<MembershipRequest>> listMembershipRequests(
    String communityId,
  ) async => [];

  @override
  Future<void> decideMembershipRequest(
    String communityId,
    String userId, {
    required bool approve,
  }) async {}

  @override
  Future<List<CommunityPost>> listPendingPosts(String communityId) async =>
      List.unmodifiable(
        (_posts[communityId] ?? const []).where(
          (post) => post.status == PostStatus.pendingApproval,
        ),
      );

  @override
  Future<List<CommunityPost>> listRemovedPosts(String communityId) async =>
      List.unmodifiable(
        (_posts[communityId] ?? const []).where(
          (post) => post.status == PostStatus.removed,
        ),
      );

  @override
  Future<void> restorePost(
    String communityId,
    String postId, {
    required String reason,
  }) async {
    final posts = _posts[communityId];
    if (posts == null) return;
    final index = posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    final post = posts[index];
    posts[index] = CommunityPost(
      id: post.id,
      communityId: post.communityId,
      categoryId: post.categoryId,
      authorId: post.authorId,
      text: post.text,
      status: PostStatus.published,
      createdAt: post.createdAt,
      media: post.media,
      authorName: post.authorName,
      authorAvatarUrl: post.authorAvatarUrl,
      reactionCount: post.reactionCount,
      commentCount: post.commentCount,
      reactedByMe: post.reactedByMe,
      savedByMe: post.savedByMe,
      ownedByMe: post.ownedByMe,
      editedAt: post.editedAt,
      promotion: post.promotion,
      poll: post.poll,
      todayMenu: post.todayMenu,
      businessFeature: post.businessFeature,
      mentionedUserIds: post.mentionedUserIds,
      isAnonymous: post.isAnonymous,
    );
  }

  @override
  Future<void> moderatePost(
    String communityId,
    String postId, {
    required bool approve,
    String? reason,
  }) async {}

  @override
  Future<PromotionEligibility> getPromotionEligibility() async =>
      PromotionEligibility(
        eligible: true,
        trialStarted: _promotions.isNotEmpty,
        trialDays: 30,
        maxCampaignDays: 7,
        activeCampaignId: _promotions
            .where(
              (item) =>
                  item.status == PromotionStatus.pending ||
                  item.status == PromotionStatus.active,
            )
            .firstOrNull
            ?.id,
      );

  @override
  Future<List<PromotionCampaign>> listMyPromotions() async =>
      List.unmodifiable(_promotions.reversed);

  @override
  Future<PromotionCampaign> createPromotion(
    String postId, {
    required int durationDays,
  }) async {
    final post = await getPost(postId);
    final campaign = PromotionCampaign(
      id: 'promotion-${_promotions.length + 1}',
      postId: postId,
      communityId: post.communityId,
      status: PromotionStatus.pending,
      durationDays: durationDays,
      impressionCount: 0,
      clickCount: 0,
      createdAt: DateTime.now(),
    );
    _promotions.add(campaign);
    return campaign;
  }

  @override
  Future<void> cancelPromotion(String promotionId) async {}

  @override
  Future<void> recordPromotionImpression(String promotionId) async {}

  @override
  Future<void> recordPromotionClick(String promotionId) async {}

  @override
  Future<List<PromotionCampaign>> listPendingPromotions(
    String communityId,
  ) async => _promotions
      .where(
        (item) =>
            item.communityId == communityId &&
            item.status == PromotionStatus.pending,
      )
      .toList();

  @override
  Future<void> reviewPromotion(
    String communityId,
    String promotionId, {
    required bool approve,
    String? reason,
  }) async {}

  @override
  Future<List<BlockedUser>> listBlockedUsers() async =>
      List.unmodifiable(_blockedUsers);

  @override
  Future<void> blockUser(String userId) async {
    if (_blockedUsers.any((item) => item.userId == userId)) return;
    _blockedUsers.add(BlockedUser(userId: userId, name: 'Wicchu member'));
  }

  @override
  Future<void> unblockUser(String userId) async =>
      _blockedUsers.removeWhere((item) => item.userId == userId);

  final List<DirectMessage> _directMessages = [];

  @override
  Future<List<DirectConversation>> listDirectConversations({
    String? pageId,
  }) async => const [];

  @override
  Future<List<DirectConversation>> listMessageRequests({
    String? pageId,
  }) async => const [];

  @override
  Future<DirectConversation> startDirectConversation(String userId) async =>
      DirectConversation(
        id: 'demo-$userId',
        otherUser: WicchuUser(id: userId, name: 'Wicchu member'),
        unreadCount: 0,
        requestStatus: MessageRequestStatus.pending,
        requestedByMe: true,
      );

  @override
  Future<DirectConversation> startPageConversation(String pageId) async {
    final page = _communities.where((item) => item.id == pageId).firstOrNull;
    return DirectConversation(
      id: 'demo-page-$pageId',
      otherUser: WicchuUser(
        id: pageId,
        name: page?.name ?? 'Wicchu page',
        avatarUrl: page?.imageUrl,
      ),
      unreadCount: 0,
      requestStatus: MessageRequestStatus.pending,
      requestedByMe: true,
      pageId: pageId,
      pageName: page?.name ?? 'Wicchu page',
      otherIsPage: true,
      communityInbox: page != null && !page.isPublicProfile,
    );
  }

  @override
  Future<void> updateDirectConversationLabel(
    String conversationId,
    ConversationLabel label,
  ) async {}

  @override
  Future<void> respondToMessageRequest(
    String conversationId, {
    required bool accept,
  }) async {}

  @override
  Future<DirectMessagePage> listDirectMessages(
    String conversationId, {
    String? before,
  }) async => DirectMessagePage(
    messages: _directMessages
        .where((item) => item.conversationId == conversationId)
        .toList(growable: false),
  );

  @override
  Future<void> markDirectConversationRead(String conversationId) async {}

  @override
  Future<DirectMessage> sendDirectMessage(
    String conversationId,
    String body,
  ) async {
    final message = DirectMessage(
      id: 'demo-message-${_directMessages.length + 1}',
      conversationId: conversationId,
      senderId: 'user-1',
      recipientId: 'demo-recipient',
      body: body,
      createdAt: DateTime.now(),
      sentByMe: true,
    );
    _directMessages.add(message);
    return message;
  }

  @override
  Future<void> deleteDirectMessage(
    String messageId, {
    required bool everyone,
  }) async => _directMessages.removeWhere((item) => item.id == messageId);

  @override
  Future<void> deleteDirectConversation(String conversationId) async =>
      _directMessages.removeWhere(
        (item) => item.conversationId == conversationId,
      );

  MessagingPrivacy _messagingPrivacy = MessagingPrivacy.everyone;

  @override
  Future<MessagingPrivacy> getMessagingPrivacy() async => _messagingPrivacy;

  @override
  Future<MessagingPrivacy> updateMessagingPrivacy(
    MessagingPrivacy value,
  ) async => _messagingPrivacy = value;

  @override
  Future<void> reportDirectMessage(
    String messageId,
    String reason, {
    required String category,
  }) async {}

  static String _iconFor(String name) => switch (name) {
    'News' => '📢',
    'Marketplace' => '🛒',
    'Jobs' => '💼',
    'Events' => '🎉',
    'Local Businesses' => '🏪',
    'Housing' => '🏠',
    'Politics' => '🏛',
    _ => '💬',
  };
}
