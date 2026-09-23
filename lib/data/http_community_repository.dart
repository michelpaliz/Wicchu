import '../domain/community_models.dart';
import '../domain/community_repository.dart';
import 'authenticated_api_client.dart';

class HttpCommunityRepository implements CommunityRepository {
  HttpCommunityRepository({AuthenticatedApiClient? apiClient})
    : _api = apiClient ?? AuthenticatedApiClient();

  final AuthenticatedApiClient _api;

  @override
  Future<WicchuProfile> getProfile() async {
    final body = await _api.get('/api/community/v1/me');
    final json = _object(body, 'user');
    return WicchuProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      location: json['location'] as String?,
      communityCount: (json['communityCount'] as num?)?.toInt() ?? 0,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      savedPostCount: (json['savedPostCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<PublicMemberProfile> getMemberProfile(String userId) async {
    final body = await _api.get('/api/community/v1/users/$userId');
    final json = _object(body, 'user');
    return PublicMemberProfile(
      id: json['id']?.toString() ?? userId,
      name: json['name']?.toString() ?? 'Wicchu member',
      userName: json['userName']?.toString() ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      communityCount: (json['communityCount'] as num?)?.toInt() ?? 0,
      socialLinks: _socialLinksFromJson(json['socialLinks']),
      isOnline: json['isOnline'] == true,
      lastActiveAt: _optionalDate(json['lastActiveAt']),
    );
  }

  @override
  Future<SocialLinks> getMySocialLinks() async {
    final body = await _api.get('/api/community/v1/me/social-links');
    return _socialLinksFromJson({
      ..._object(body, 'socialLinks'),
      'showOnlineStatus': body['showOnlineStatus'],
    });
  }

  @override
  Future<SocialLinks> updateMySocialLinks(SocialLinks links) async {
    final body = await _api.patch(
      '/api/community/v1/me/social-links',
      body: {
        'whatsapp': links.whatsapp,
        'facebook': links.facebook,
        'instagram': links.instagram,
        'email': links.email,
        'showOnlineStatus': links.showOnlineStatus,
      },
    );
    return _socialLinksFromJson({
      ..._object(body, 'socialLinks'),
      'showOnlineStatus': body['showOnlineStatus'],
    });
  }

  static SocialLinks _socialLinksFromJson(Object? value) {
    final json = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    return SocialLinks(
      whatsapp: json['whatsapp']?.toString() ?? '',
      facebook: json['facebook']?.toString() ?? '',
      instagram: json['instagram']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
    );
  }

  @override
  Future<List<CommunityPost>> listMemberPosts(
    String userId, {
    String kind = 'all',
    String sort = 'newest',
  }) async {
    final uri = Uri(
      path: '/api/community/v1/users/$userId/posts',
      queryParameters: {'kind': kind, 'sort': sort},
    );
    final body = await _api.get(uri.toString());
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<NotificationFeed> listNotifications() async {
    final body = await _api.get('/api/community/v1/me/notifications');
    return NotificationFeed(
      items: _list(
        body,
        'notifications',
      ).map(_notificationFromJson).toList(growable: false),
      unreadCount: (body['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _api.patch('/api/community/v1/me/notifications/$notificationId');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _api.patch('/api/community/v1/me/notifications/read-all');
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences() async =>
      _preferencesFromJson(
        await _api.get('/api/community/v1/me/notification-preferences'),
      );

  @override
  Future<NotificationPreferences> updateNotificationPreferences({
    bool? postActivity,
    bool? communityActivity,
    bool? promotions,
  }) async => _preferencesFromJson(
    await _api.patch(
      '/api/community/v1/me/notification-preferences',
      body: {
        'postActivity': ?postActivity,
        'communityActivity': ?communityActivity,
        'promotions': ?promotions,
      },
    ),
  );

  @override
  Future<void> registerDeviceToken(
    String token, {
    required String platform,
  }) async {
    await _api.post(
      '/api/community/v1/me/devices',
      body: {'token': token, 'platform': platform},
    );
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    await _api.delete(
      '/api/community/v1/me/devices?token=${Uri.encodeQueryComponent(token)}',
    );
  }

  @override
  Future<List<Town>> listTowns() async {
    final body = await _api.get('/api/community/v1/towns');
    return _list(body, 'towns').map(_townFromJson).toList(growable: false);
  }

  @override
  Future<Town> locateTown({
    required double latitude,
    required double longitude,
  }) async {
    final body = await _api.post(
      '/api/community/v1/towns/resolve',
      body: {'latitude': latitude, 'longitude': longitude},
    );
    final value = body['town'];
    if (value is! Map<String, dynamic>) {
      final location = body['location'];
      final name = location is Map<String, dynamic>
          ? location['name']?.toString()
          : null;
      throw ApiException(
        name == null
            ? 'No town was found near your location.'
            : 'Unable to register $name. Please try again.',
      );
    }
    return _townFromJson(value);
  }

  @override
  Future<List<Community>> listManagedCommunities() async {
    final body = await _api.get('/api/community/v1/communities?managed=true');
    return _list(
      body,
      'communities',
    ).map(_communityFromJson).toList(growable: false);
  }

  @override
  Future<List<Community>> listCommunities({String? query}) => _listCommunities(
    query == null || query.trim().isEmpty
        ? ''
        : '?q=${Uri.encodeQueryComponent(query.trim())}',
  );

  @override
  Future<List<Community>> listJoinedCommunities() =>
      _listCommunities('?joined=true');

  @override
  Future<List<Community>> listNearbyCommunities({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
  }) async {
    final uri = Uri(
      path: '/api/community/v1/communities/nearby',
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radiusKm': '$radiusKm',
      },
    );
    final body = await _api.get(uri.toString());
    return _list(
      body,
      'communities',
    ).map(_communityFromJson).toList(growable: false);
  }

  Future<List<Community>> _listCommunities(String query) async {
    final body = await _api.get('/api/community/v1/communities$query');
    return _list(
      body,
      'communities',
    ).map(_communityFromJson).toList(growable: false);
  }

  @override
  Future<Community> createCommunity(CreateCommunityInput input) async {
    final body = await _api.post(
      '/api/community/v1/communities',
      body: {
        'name': input.name,
        'description': input.description,
        'townId': input.town.id,
        'visibility': input.visibility.name,
        'categoryNames': input.categoryNames,
        'approvalRequired': input.approvalRequired,
        'rules': input.rules
            .map(
              (rule) => {
                'title': rule.title,
                'description': rule.description,
              },
            )
            .toList(),
      },
    );
    final json = _object(body, 'community');
    return _communityFromJson({
      ...json,
      'town': _townToJson(input.town),
      'myRole': 'owner',
      'memberCount': 1,
    });
  }

  @override
  Future<void> joinCommunity(String communityId) async {
    await _api.post('/api/community/v1/communities/$communityId/join');
  }

  @override
  Future<CommunityInvitation> createCommunityInvitation(
    String communityId,
    String email,
  ) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/invitations',
      body: {'email': email},
    );
    return _invitationFromJson(
      _object(body, 'invitation'),
      invitationUrl: body['invitationUrl']?.toString(),
    );
  }

  @override
  Future<List<CommunityInvitation>> listCommunityInvitations(String communityId) async {
    final body = await _api.get('/api/community/v1/communities/$communityId/invitations');
    return _list(body, 'invitations').map(_invitationFromJson).toList(growable: false);
  }

  @override
  Future<List<CommunityInvitation>> listMyCommunityInvitations() async {
    final body = await _api.get('/api/community/v1/me/invitations');
    return _list(body, 'invitations').map(_invitationFromJson).toList(growable: false);
  }

  @override
  Future<void> respondToCommunityInvitation(String invitationId, {required bool accept}) async {
    await _api.post('/api/community/v1/me/invitations/$invitationId/${accept ? 'accept' : 'decline'}');
  }

  @override
  Future<void> revokeCommunityInvitation(String communityId, String invitationId) async {
    await _api.delete('/api/community/v1/communities/$communityId/invitations/$invitationId');
  }

  @override
  Future<CommunityRules> listRules(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/rules',
    );
    return CommunityRules(
      rules: _list(body, 'rules').map(_ruleFromJson).toList(growable: false),
      rulesVersion: (body['rulesVersion'] as num?)?.toInt() ?? 0,
      acceptedRulesVersion:
          (body['acceptedRulesVersion'] as num?)?.toInt() ?? 0,
      acceptanceRequired: body['acceptanceRequired'] == true,
      canManage: body['canManage'] == true,
    );
  }

  @override
  Future<CommunityRule> createRule(
    String communityId, {
    required String title,
    required String description,
    required int position,
  }) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/rules',
      body: {
        'title': title,
        'description': description,
        'position': position,
      },
    );
    return _ruleFromJson(_object(body, 'rule'));
  }

  @override
  Future<CommunityRule> updateRule(
    String communityId,
    CommunityRule rule, {
    String? title,
    String? description,
    int? position,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/communities/$communityId/rules/${rule.id}',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (position != null) 'position': position,
      },
    );
    return _ruleFromJson(_object(body, 'rule'));
  }

  @override
  Future<void> deleteRule(String communityId, String ruleId) async {
    await _api.delete(
      '/api/community/v1/communities/$communityId/rules/$ruleId',
    );
  }

  @override
  Future<void> acceptRules(String communityId, int rulesVersion) async {
    await _api.post(
      '/api/community/v1/communities/$communityId/rules/accept',
      body: {'rulesVersion': rulesVersion},
    );
  }

  @override
  Future<void> leaveCommunity(String communityId) async {
    await _api.delete('/api/community/v1/communities/$communityId/membership');
  }

  @override
  Future<List<CommunityCategory>> listCategories(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/categories',
    );
    return _list(
      body,
      'categories',
    ).map(_categoryFromJson).toList(growable: false);
  }

  @override
  Future<CommunityCategory> createCategory(
    String communityId, {
    required String name,
    String description = '',
  }) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/categories',
      body: {'name': name, 'description': description},
    );
    return _categoryFromJson(_object(body, 'category'));
  }

  @override
  Future<CommunityCategory> updateCategory(
    String communityId,
    CommunityCategory category, {
    required String name,
    required String description,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/communities/$communityId/categories/${category.id}',
      body: {'name': name, 'description': description},
    );
    return _categoryFromJson(_object(body, 'category'));
  }

  @override
  Future<void> deleteCategory(String communityId, String categoryId) async {
    await _api.delete(
      '/api/community/v1/communities/$communityId/categories/$categoryId',
    );
  }

  @override
  Future<List<CommunityMember>> listMembers(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/members',
    );
    return _list(body, 'members')
        .map((json) {
          final user = json['user'];
          final userJson = user is Map<String, dynamic>
              ? user
              : const <String, dynamic>{};
          return CommunityMember(
            userId: json['userId']?.toString() ?? '',
            communityId: json['communityId']?.toString() ?? communityId,
            name:
                userJson['name'] as String? ??
                json['userName'] as String? ??
                'Member ${json['userId']?.toString().substring(0, 6) ?? ''}',
            avatarUrl: userJson['avatarUrl'] as String?,
            role: _roleFromJson(json['role']) ?? CommunityRole.member,
            status: switch (json['status']) {
              'pending' => MembershipStatus.pending,
              'banned' => MembershipStatus.banned,
              _ => MembershipStatus.active,
            },
            joinedAt:
                DateTime.tryParse(json['joinedAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            isOnline: json['isOnline'] == true,
            lastActiveAt: _optionalDate(json['lastActiveAt']),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> setMemberRole(
    String communityId,
    String userId,
    CommunityRole role,
  ) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/members/$userId/role',
      body: {'role': role.name},
    );
  }

  @override
  Future<Community> updateCommunity(
    Community community, {
    required String name,
    required String description,
    required CommunityVisibility visibility,
    required bool approvalRequired,
    String? imageUrl,
    String? imageBlobName,
    List<CommunityRule>? rules,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/communities/${community.id}',
      body: {
        'name': name,
        'description': description,
        'visibility': visibility.name,
        'approvalRequired': approvalRequired,
        'imageBlobName': ?imageBlobName,
        if (rules != null)
          'rules': [
            for (final rule in rules)
              {'title': rule.title, 'description': rule.description},
          ],
      },
    );
    final updated = _communityFromJson({
      ..._object(body, 'community'),
      'town': _townToJson(community.town),
      'memberCount': community.memberCount,
      'myRole': community.myRole?.name,
    });
    if (rules != null &&
        (_object(body, 'community')['rules'] is! List ||
            updated.rules.length != rules.length ||
            List.generate(rules.length, (i) => i).any(
              (i) =>
                  updated.rules[i].title != rules[i].title ||
                  updated.rules[i].description != rules[i].description,
            ))) {
      throw const ApiException(
        'The server did not confirm the rules. Your draft is still here; other settings may have saved.',
      );
    }
    return updated;
  }

  @override
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  }) async {
    final parameters = <String, String>{
      'categoryId': ?categoryId,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (sort != null && sort.isNotEmpty) 'sort': sort,
    };
    final uri = Uri(
      path: '/api/community/v1/communities/$communityId/posts',
      queryParameters: parameters.isEmpty ? null : parameters,
    );
    final body = await _api.get(uri.toString());
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<List<CommunityPost>> listFollowingPosts({String? query}) async {
    final uri = Uri(
      path: '/api/community/v1/posts',
      queryParameters: query == null || query.trim().isEmpty
          ? null
          : {'q': query.trim()},
    );
    final body = await _api.get(uri.toString());
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<CommunityPost> getPost(String postId) async {
    final body = await _api.get('/api/community/v1/posts/$postId');
    return _postFromJson(_object(body, 'post'));
  }

  @override
  Future<SharedPostPreview> getSharedPost(String postId) async {
    final body = await _api.get('/wicchu/api/posts/$postId');
    final postJson = _object(body, 'post');
    final community = _object(body, 'community');
    final category = _object(body, 'category');
    final author = _object(body, 'author');
    return SharedPostPreview(
      post: _postFromJson({
        ...postJson,
        'communityId': community['id'],
        'categoryId': category['id'],
        'author': {'name': author['name']},
        'media': postJson['imageUrl'] == null
            ? const []
            : [
                {'type': 'image', 'url': postJson['imageUrl']},
              ],
        'status': 'published',
      }),
      communityId: community['id']?.toString() ?? '',
      communityName: community['name'] as String? ?? 'Wicchu',
      communityDescription: community['description'] as String? ?? '',
      communityImageUrl: community['imageUrl'] as String?,
      categoryName: category['name'] as String? ?? 'Post',
      categoryIcon: category['icon'] as String? ?? '💬',
    );
  }

  @override
  Future<void> recordPostShare(String postId) async {
    await _api.post('/api/community/v1/posts/$postId/share');
  }

  @override
  Future<CommunityPost> createPost(
    String communityId,
    CreatePostInput input,
  ) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/posts',
      body: {
        'categoryId': input.categoryId,
        'text': input.text,
        'media': input.media
            .map(
              (item) => {
                'type': item.type,
                'blobName': item.blobName,
                'url': item.url,
              },
            )
            .toList(),
        if (input.pollOptions.isNotEmpty) 'pollOptions': input.pollOptions,
      },
    );
    return _postFromJson(_object(body, 'post'));
  }

  @override
  Future<CommunityPost> updatePost(String postId, CreatePostInput input) async {
    final body = await _api.patch(
      '/api/community/v1/posts/$postId',
      body: {
        'categoryId': input.categoryId,
        'text': input.text,
        'media': input.media
            .map(
              (item) => {
                'type': item.type,
                'blobName': item.blobName,
                'url': item.url,
              },
            )
            .toList(),
        'pollOptions': input.pollOptions,
      },
    );
    return _postFromJson(_object(body, 'post'));
  }

  @override
  Future<void> deletePost(String postId) async {
    await _api.delete('/api/community/v1/posts/$postId');
  }

  @override
  Future<PostMedia> uploadPostMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final body = await _api.upload(
      '/api/community/v1/media/uploads',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
    final media = _object(body, 'media');
    return PostMedia(
      url: media['url'] as String? ?? '',
      type: media['type'] as String? ?? 'image',
      blobName: media['blobName'] as String?,
    );
  }

  @override
  Future<int> setPostReaction(String postId, {required bool reacted}) async {
    final path = '/api/community/v1/posts/$postId/reaction';
    final body = reacted ? await _api.put(path) : await _api.delete(path);
    return (body['reactionCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<PostPoll> voteOnPost(String postId, String optionId) async {
    final body = await _api.put(
      '/api/community/v1/posts/$postId/poll-vote',
      body: {'optionId': optionId},
    );
    return _pollFromJson(_object(body, 'poll'));
  }

  @override
  Future<List<Comment>> listComments(String postId) async {
    final body = await _api.get('/api/community/v1/posts/$postId/comments');
    return _list(
      body,
      'comments',
    ).map(_commentFromJson).toList(growable: false);
  }

  @override
  Future<Comment> createComment(
    String postId,
    String text, {
    String? parentCommentId,
  }) async {
    final body = await _api.post(
      '/api/community/v1/posts/$postId/comments',
      body: {'text': text, 'parentCommentId': ?parentCommentId},
    );
    return _commentFromJson(_object(body, 'comment'));
  }

  @override
  Future<int> setCommentReaction(
    String commentId, {
    required bool reacted,
  }) async {
    final path = '/api/community/v1/comments/$commentId/reaction';
    final body = reacted ? await _api.put(path) : await _api.delete(path);
    return (body['reactionCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<CommunityPost>> listMyPosts() async {
    final body = await _api.get('/api/community/v1/me/posts');
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<List<CommunityPost>> listSavedPosts() async {
    final body = await _api.get('/api/community/v1/me/saved-posts');
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<void> setPostSaved(String postId, {required bool saved}) async {
    final path = '/api/community/v1/me/saved-posts/$postId';
    if (saved) {
      await _api.put(path);
    } else {
      await _api.delete(path);
    }
  }

  @override
  Future<void> reportPost(String postId, String reason) async {
    await _api.post(
      '/api/community/v1/posts/$postId/reports',
      body: {'reason': reason},
    );
  }

  @override
  Future<AdminAttentionSummary> getAdminAttention(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/summary',
    );
    final summary = _object(body, 'summary');
    return AdminAttentionSummary(
      pendingPosts: (summary['pendingPosts'] as num?)?.toInt() ?? 0,
      openReports: (summary['openReports'] as num?)?.toInt() ?? 0,
      membershipRequests: (summary['membershipRequests'] as num?)?.toInt() ?? 0,
      pendingPromotions: (summary['pendingPromotions'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<CommunityPost>> listPendingPosts(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/pending-posts',
    );
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<void> moderatePost(
    String communityId,
    String postId, {
    required bool approve,
    String? reason,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/admin/pending-posts/$postId',
      body: {'decision': approve ? 'approve' : 'reject', 'reason': ?reason},
    );
  }

  @override
  Future<List<CommunityReport>> listReports(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/reports',
    );
    return _list(body, 'reports')
        .map(
          (json) => CommunityReport(
            id: _id(json),
            reporterId: json['reporterId']?.toString() ?? '',
            communityId: json['communityId']?.toString() ?? '',
            targetType: ModerationTargetType.post,
            targetId: json['targetId']?.toString() ?? '',
            reason: json['reason'] as String? ?? '',
            status: ReportStatus.open,
            createdAt:
                DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> decideReport(
    String communityId,
    String reportId, {
    required bool resolve,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/admin/reports/$reportId',
      body: {'decision': resolve ? 'resolve' : 'dismiss'},
    );
  }

  @override
  Future<List<MembershipRequest>> listMembershipRequests(
    String communityId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/membership-requests',
    );
    return _list(body, 'requests')
        .map((json) {
          final user = json['user'] is Map<String, dynamic>
              ? json['user'] as Map<String, dynamic>
              : const <String, dynamic>{};
          return MembershipRequest(
            userId: json['userId']?.toString() ?? '',
            userName: user['name'] as String? ?? 'Wicchu member',
            createdAt:
                DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> decideMembershipRequest(
    String communityId,
    String userId, {
    required bool approve,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/admin/membership-requests/$userId',
      body: {'decision': approve ? 'approve' : 'reject'},
    );
  }

  @override
  Future<PromotionEligibility> getPromotionEligibility() async {
    final body = await _api.get('/api/community/v1/promotions/eligibility');
    final json = _object(body, 'eligibility');
    return PromotionEligibility(
      eligible: json['eligible'] as bool? ?? false,
      trialStarted: json['trialStarted'] as bool? ?? false,
      trialDays: (json['trialDays'] as num?)?.toInt() ?? 30,
      maxCampaignDays: (json['maxCampaignDays'] as num?)?.toInt() ?? 7,
      startedAt: _optionalDate(json['startedAt']),
      expiresAt: _optionalDate(json['expiresAt']),
      activeCampaignId: json['activeCampaignId']?.toString(),
      townId: json['townId']?.toString(),
    );
  }

  @override
  Future<List<PromotionCampaign>> listMyPromotions() async {
    final body = await _api.get('/api/community/v1/promotions/mine');
    return _list(body, 'campaigns').map(_promotionFromJson).toList();
  }

  @override
  Future<PromotionCampaign> createPromotion(
    String postId, {
    required int durationDays,
  }) async {
    final body = await _api.post(
      '/api/community/v1/promotions',
      body: {'postId': postId, 'durationDays': durationDays},
    );
    return _promotionFromJson(_object(body, 'campaign'));
  }

  @override
  Future<void> cancelPromotion(String promotionId) async {
    await _api.patch('/api/community/v1/promotions/$promotionId/cancel');
  }

  @override
  Future<void> recordPromotionImpression(String promotionId) async {
    await _api.post('/api/community/v1/promotions/$promotionId/impression');
  }

  @override
  Future<void> recordPromotionClick(String promotionId) async {
    await _api.post('/api/community/v1/promotions/$promotionId/click');
  }

  @override
  Future<List<PromotionCampaign>> listPendingPromotions(
    String communityId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/promotions',
    );
    return _list(body, 'campaigns').map(_promotionFromJson).toList();
  }

  @override
  Future<void> reviewPromotion(
    String communityId,
    String promotionId, {
    required bool approve,
    String? reason,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/admin/promotions/$promotionId',
      body: {'decision': approve ? 'approve' : 'reject', 'reason': ?reason},
    );
  }

  static List<Map<String, dynamic>> _list(
    Map<String, dynamic> body,
    String key,
  ) {
    final value = body[key];
    if (value is! List) throw ApiException('Invalid $key response.');
    return value.cast<Map<String, dynamic>>();
  }

  static Map<String, dynamic> _object(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is! Map<String, dynamic>) {
      throw ApiException('Invalid $key response.');
    }
    return value;
  }

  static Town _townFromJson(Map<String, dynamic> json) => Town(
    id: _id(json),
    name: json['name'] as String? ?? '',
    countryCode: json['countryCode'] as String? ?? '',
  );

  static CommunityRule _ruleFromJson(Map<String, dynamic> json) =>
      CommunityRule(
        id: _id(json),
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        position: (json['position'] as num?)?.toInt() ?? 0,
      );

  static Map<String, dynamic> _townToJson(Town town) => {
    '_id': town.id,
    'name': town.name,
    'countryCode': town.countryCode,
  };

  static Community _communityFromJson(Map<String, dynamic> json) {
    final townJson = json['town'];
    if (townJson is! Map<String, dynamic>) {
      throw const ApiException('Community town data is missing.');
    }
    return Community(
      id: _id(json),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      town: _townFromJson(townJson),
      imageUrl: json['imageUrl'] as String?,
      visibility: json['visibility'] == 'private'
          ? CommunityVisibility.private
          : CommunityVisibility.public,
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
      myRole: switch (json['myRole']) {
        'owner' => CommunityRole.owner,
        'admin' => CommunityRole.admin,
        'moderator' => CommunityRole.moderator,
        'member' => CommunityRole.member,
        _ => null,
      },
      approvalRequired: json['approvalRequired'] as bool? ?? false,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      rules: (json['rules'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (rule) => CommunityRule(
              id: _id(rule),
              title: rule['title']?.toString() ?? '',
              description: rule['description']?.toString() ?? '',
              position: (rule['position'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((rule) => rule.title.isNotEmpty)
          .toList(growable: false),
    );
  }

  static CommunityCategory _categoryFromJson(Map<String, dynamic> json) =>
      CommunityCategory(
        id: _id(json),
        communityId: json['communityId']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? '💬',
        rules:
            (json['rules'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
      );

  static CommunityPost _postFromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final authorJson = author is Map<String, dynamic>
        ? author
        : const <String, dynamic>{};
    return CommunityPost(
      id: _id(json),
      communityId: json['communityId']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      authorId:
          authorJson['id']?.toString() ?? json['authorId']?.toString() ?? '',
      authorName: authorJson['name'] as String? ?? 'Wicchu member',
      authorAvatarUrl: authorJson['avatarUrl'] as String?,
      text: json['text'] as String? ?? '',
      media: (json['media'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => PostMedia(
              url: item['url'] as String? ?? '',
              type: item['type'] as String? ?? 'image',
              blobName: item['blobName'] as String?,
            ),
          )
          .toList(growable: false),
      status: switch (json['status']) {
        'pending_approval' || 'pendingApproval' => PostStatus.pendingApproval,
        'removed' => PostStatus.removed,
        _ => PostStatus.published,
      },
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      reactedByMe: json['reactedByMe'] as bool? ?? false,
      savedByMe: json['savedByMe'] as bool? ?? false,
      ownedByMe: json['ownedByMe'] as bool? ?? false,
      editedAt: _optionalDate(json['editedAt']),
      promotion: json['promotion'] is Map<String, dynamic>
          ? _postPromotionFromJson(json['promotion'] as Map<String, dynamic>)
          : null,
      poll: json['poll'] is Map<String, dynamic>
          ? _pollFromJson(json['poll'] as Map<String, dynamic>)
          : null,
    );
  }

  static PostPoll _pollFromJson(Map<String, dynamic> json) => PostPoll(
    options: (json['options'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (option) => PollOption(
            id: (option['id'] ?? option['_id'])?.toString() ?? '',
            text: option['text']?.toString() ?? '',
            voteCount: (option['voteCount'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false),
    selectedOptionId: json['selectedOptionId']?.toString(),
  );

  static PostPromotion _postPromotionFromJson(Map<String, dynamic> json) =>
      PostPromotion(
        id: _id(json),
        startsAt: _date(json['startsAt']),
        endsAt: _date(json['endsAt']),
      );

  static PromotionCampaign _promotionFromJson(Map<String, dynamic> json) =>
      PromotionCampaign(
        id: _id(json),
        postId: json['postId']?.toString() ?? '',
        communityId: json['communityId']?.toString() ?? '',
        status: PromotionStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => PromotionStatus.pending,
        ),
        durationDays: (json['durationDays'] as num?)?.toInt() ?? 7,
        impressionCount: (json['impressionCount'] as num?)?.toInt() ?? 0,
        clickCount: (json['clickCount'] as num?)?.toInt() ?? 0,
        createdAt: _date(json['createdAt']),
        startsAt: _optionalDate(json['startsAt']),
        endsAt: _optionalDate(json['endsAt']),
        rejectionReason: json['rejectionReason'] as String? ?? '',
      );

  static DateTime _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime? _optionalDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  static Comment _commentFromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final authorJson = author is Map<String, dynamic>
        ? author
        : const <String, dynamic>{};
    return Comment(
      id: _id(json),
      postId: json['postId']?.toString() ?? '',
      authorId:
          authorJson['id']?.toString() ?? json['authorId']?.toString() ?? '',
      authorName: authorJson['name'] as String? ?? 'Wicchu member',
      authorAvatarUrl: authorJson['avatarUrl'] as String?,
      text: json['text'] as String? ?? '',
      parentCommentId: json['parentCommentId']?.toString(),
      reactionCount: (json['reactionCount'] as num?)?.toInt() ?? 0,
      reactedByMe: json['reactedByMe'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static CommunityNotification _notificationFromJson(
    Map<String, dynamic> json,
  ) {
    final actor = json['actor'];
    final actorJson = actor is Map<String, dynamic>
        ? actor
        : const <String, dynamic>{};
    return CommunityNotification(
      id: _id(json),
      actorName: actorJson['name'] as String? ?? 'Wicchu member',
      actorAvatarUrl: actorJson['avatarUrl'] as String?,
      type: _notificationType(json['type']?.toString()),
      postId: json['postId']?.toString() ?? '',
      communityId: json['communityId']?.toString() ?? '',
      promotionId: json['promotionId']?.toString() ?? '',
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isRead: json['readAt'] != null || json['isRead'] == true,
    );
  }

  static NotificationPreferences _preferencesFromJson(
    Map<String, dynamic> body,
  ) {
    final value = body['preferences'];
    final json = value is Map<String, dynamic> ? value : body;
    return NotificationPreferences(
      postActivity: json['postActivity'] as bool? ?? true,
      communityActivity: json['communityActivity'] as bool? ?? true,
      promotions: json['promotions'] as bool? ?? true,
    );
  }

  static CommunityNotificationType _notificationType(String? value) =>
      switch (value) {
        'post_comment' ||
        'postComment' => CommunityNotificationType.postComment,
        'comment_reaction' => CommunityNotificationType.commentReaction,
        'comment_reply' => CommunityNotificationType.commentReply,
        'post_approved' => CommunityNotificationType.postApproved,
        'post_rejected' => CommunityNotificationType.postRejected,
        'post_removed' => CommunityNotificationType.postRemoved,
        'post_restored' => CommunityNotificationType.postRestored,
        'comment_approved' => CommunityNotificationType.commentApproved,
        'comment_rejected' => CommunityNotificationType.commentRejected,
        'comment_removed' => CommunityNotificationType.commentRemoved,
        'member_banned' => CommunityNotificationType.memberBanned,
        'member_unbanned' => CommunityNotificationType.memberUnbanned,
        'membership_approved' => CommunityNotificationType.membershipApproved,
        'membership_rejected' => CommunityNotificationType.membershipRejected,
        'promotion_approved' => CommunityNotificationType.promotionApproved,
        'promotion_rejected' => CommunityNotificationType.promotionRejected,
        'membership_request' => CommunityNotificationType.membershipRequest,
        'post_pending' => CommunityNotificationType.postPending,
        'comment_pending' => CommunityNotificationType.commentPending,
        'report_created' => CommunityNotificationType.reportCreated,
        'community_invitation' => CommunityNotificationType.communityInvitation,
        'community_role_changed' => CommunityNotificationType.communityRoleChanged,
        _ => CommunityNotificationType.postReaction,
      };

  static String _id(Map<String, dynamic> json) =>
      (json['_id'] ?? json['id'])?.toString() ?? '';

  static CommunityInvitation _invitationFromJson(
    Map<String, dynamic> json, {
    String? invitationUrl,
  }) {
    final community = json['community'];
    final communityJson = community is Map<String, dynamic>
        ? community
        : const <String, dynamic>{};
    return CommunityInvitation(
      id: _id(json),
      communityId: json['communityId']?.toString() ?? communityJson['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      communityName: communityJson['name']?.toString(),
      communityImageUrl: communityJson['imageUrl']?.toString(),
      invitationUrl: invitationUrl,
    );
  }

  static CommunityRole? _roleFromJson(Object? value) => switch (value) {
    'owner' => CommunityRole.owner,
    'admin' => CommunityRole.admin,
    'moderator' => CommunityRole.moderator,
    'member' => CommunityRole.member,
    _ => null,
  };
}
