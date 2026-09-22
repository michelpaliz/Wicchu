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
            role: _roleFromJson(json['role']) ?? CommunityRole.member,
            status: switch (json['status']) {
              'pending' => MembershipStatus.pending,
              'banned' => MembershipStatus.banned,
              _ => MembershipStatus.active,
            },
            joinedAt:
                DateTime.tryParse(json['joinedAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
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
  }) async {
    final body = await _api.patch(
      '/api/community/v1/communities/${community.id}',
      body: {
        'name': name,
        'description': description,
        'visibility': visibility.name,
        'approvalRequired': approvalRequired,
        'imageBlobName': ?imageBlobName,
      },
    );
    return _communityFromJson({
      ..._object(body, 'community'),
      'town': _townToJson(community.town),
      'memberCount': community.memberCount,
      'myRole': community.myRole?.name,
    });
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
      },
    );
    return _postFromJson(_object(body, 'post'));
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
  Future<List<Comment>> listComments(String postId) async {
    final body = await _api.get('/api/community/v1/posts/$postId/comments');
    return _list(
      body,
      'comments',
    ).map(_commentFromJson).toList(growable: false);
  }

  @override
  Future<Comment> createComment(String postId, String text) async {
    final body = await _api.post(
      '/api/community/v1/posts/$postId/comments',
      body: {'text': text},
    );
    return _commentFromJson(_object(body, 'comment'));
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
      promotion: json['promotion'] is Map<String, dynamic>
          ? _postPromotionFromJson(json['promotion'] as Map<String, dynamic>)
          : null,
    );
  }

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
      text: json['text'] as String? ?? '',
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
      type: json['type'] == 'post_comment' || json['type'] == 'postComment'
          ? CommunityNotificationType.postComment
          : CommunityNotificationType.postReaction,
      postId: json['postId']?.toString() ?? '',
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isRead: json['readAt'] != null || json['isRead'] == true,
    );
  }

  static String _id(Map<String, dynamic> json) =>
      (json['_id'] ?? json['id'])?.toString() ?? '';

  static CommunityRole? _roleFromJson(Object? value) => switch (value) {
    'owner' => CommunityRole.owner,
    'admin' => CommunityRole.admin,
    'moderator' => CommunityRole.moderator,
    'member' => CommunityRole.member,
    _ => null,
  };
}
