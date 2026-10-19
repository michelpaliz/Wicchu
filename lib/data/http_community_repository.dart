import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/community_models.dart';
import '../domain/community_repository.dart';
import '../services/analytics_service.dart';
import 'authenticated_api_client.dart';

class HttpCommunityRepository
    implements
        CommunityRepository,
        CategorySuggestionRepository,
        CategoryReorderRepository {
  HttpCommunityRepository({AuthenticatedApiClient? apiClient})
    : _api = apiClient ?? AuthenticatedApiClient();

  final AuthenticatedApiClient _api;

  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hexora.dev',
  );

  static String? _mediaUrl(String? originalUrl, Object? blobName) {
    final name = blobName?.toString().trim() ?? '';
    if (!kIsWeb || name.isEmpty) return originalUrl;
    return '$_apiBaseUrl/api/community/v1/media/content'
        '?blobName=${Uri.encodeQueryComponent(name)}';
  }

  static CommunityRewardTier? _rewardTier(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return CommunityRewardTier(
      id: value['id']?.toString() ?? '',
      monthlyRewardCents: (value['monthlyRewardCents'] as num?)?.toInt() ?? 0,
      memberTarget: (value['memberTarget'] as num?)?.toInt() ?? 0,
      monthlyActiveTarget: (value['monthlyActiveTarget'] as num?)?.toInt() ?? 0,
      postsTarget: (value['postsTarget'] as num?)?.toInt() ?? 0,
      interactionsTarget: (value['interactionsTarget'] as num?)?.toInt() ?? 0,
      contributorsTarget: (value['contributorsTarget'] as num?)?.toInt() ?? 0,
      retentionTargetPercent:
          (value['retentionTargetPercent'] as num?)?.toDouble() ?? 0,
      qualified: value['qualified'] == true,
    );
  }

  static CommunityRewardEvaluation? _rewardEvaluation(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final metrics = value['metrics'] is Map<String, dynamic>
        ? value['metrics'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final start = DateTime.tryParse(value['periodStart']?.toString() ?? '');
    final end = DateTime.tryParse(value['periodEnd']?.toString() ?? '');
    if (start == null || end == null) return null;
    return CommunityRewardEvaluation(
      id: value['id']?.toString() ?? '',
      periodStart: start,
      periodEnd: end,
      members: (metrics['members'] as num?)?.toInt() ?? 0,
      monthlyActive: (metrics['monthlyActive'] as num?)?.toInt() ?? 0,
      posts: (metrics['posts'] as num?)?.toInt() ?? 0,
      interactions: (metrics['interactions'] as num?)?.toInt() ?? 0,
      uniqueContributors: (metrics['uniqueContributors'] as num?)?.toInt() ?? 0,
      retentionPercent: (metrics['retentionPercent'] as num?)?.toDouble() ?? 0,
      tierId: value['tierId']?.toString(),
      rewardCents: (value['rewardCents'] as num?)?.toInt() ?? 0,
      currency: value['currency']?.toString() ?? 'EUR',
      status: value['status']?.toString() ?? 'not_qualified',
      reviewNote: value['reviewNote']?.toString(),
      paidAt: DateTime.tryParse(value['paidAt']?.toString() ?? ''),
    );
  }

  @override
  Future<WicchuProfile> getProfile() async {
    final body = await _api.get('/api/community/v1/me');
    final json = _object(body, 'user');
    final profile = WicchuProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      location: json['location'] as String?,
      communityCount: (json['communityCount'] as num?)?.toInt() ?? 0,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      savedPostCount: (json['savedPostCount'] as num?)?.toInt() ?? 0,
      platformModerator: json['platformModerator'] as bool? ?? false,
    );
    unawaited(AnalyticsService.instance.identifyUser(profile.id));
    return profile;
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String userName,
    required String bio,
    required String location,
  }) async {
    await _api.patch(
      '/api/community/v1/me',
      body: {
        'name': name,
        'userName': userName,
        'bio': bio,
        'location': location,
      },
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
      coverImageUrl: json['coverImageUrl'] as String?,
      shortDescription: json['shortDescription']?.toString() ?? '',
      bio: json['bio'] as String?,
      location: json['location'] is String ? json['location'] as String : null,
      followerCount: (json['followerCount'] as num?)?.toInt(),
      followingCount: (json['followingCount'] as num?)?.toInt(),
      followedByMe: json['followedByMe'] == true,
      followStatus: json['followStatus'] == null && json['followedByMe'] == true
          ? UserFollowStatus.accepted
          : _followStatus(json['followStatus']),
      isPrivate: json['isPrivate'] == true,
      canViewPersonalPosts: json['canViewPersonalPosts'] != false,
      followRequestCount: (json['followRequestCount'] as num?)?.toInt() ?? 0,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      communityCount: (json['communityCount'] as num?)?.toInt() ?? 0,
      socialLinks: _socialLinksFromJson(json['socialLinks']),
      isOnline: json['isOnline'] == true,
      lastActiveAt: _optionalDate(json['lastActiveAt']),
      accentColor: json['accentColor']?.toString() ?? 'teal',
      neonBordersEnabled: json['neonBordersEnabled'] == true,
      neonBorderAnimation: neonBorderAnimationFromApi(
        json['neonBorderAnimation'],
      ),
      neonAnimationDurationSeconds:
          (json['neonAnimationDurationSeconds'] as num?)?.toDouble() ?? 5,
    );
  }

  @override
  Future<UserFollowActionResult> followUser(String userId) async {
    final body = await _api.put('/api/community/v1/users/$userId/follow');
    final result = UserFollowActionResult(
      status: _followStatus(body['status']),
      followerCount: (body['followerCount'] as num?)?.toInt() ?? 0,
    );
    unawaited(
      AnalyticsService.instance.log(
        'user_followed',
        parameters: {'status': result.status.name},
      ),
    );
    return result;
  }

  @override
  Future<UserFollowActionResult> unfollowUser(String userId) async {
    final body = await _api.delete('/api/community/v1/users/$userId/follow');
    return UserFollowActionResult(
      status: UserFollowStatus.none,
      followerCount: (body['followerCount'] as num?)?.toInt() ?? 0,
    );
  }

  static UserFollowStatus _followStatus(Object? value) => switch (value) {
    'accepted' => UserFollowStatus.accepted,
    'pending' => UserFollowStatus.pending,
    _ => UserFollowStatus.none,
  };

  Future<UserFollowPage> _followPage(
    String userId,
    String relationship, {
    String? cursor,
  }) async {
    final uri = Uri(
      path: '/api/community/v1/users/$userId/$relationship',
      queryParameters: cursor == null ? null : {'cursor': cursor},
    );
    final body = await _api.get(uri.toString());
    return UserFollowPage(
      users: _list(body, 'users')
          .map(
            (json) => UserFollowProfile(
              id: json['id']?.toString() ?? '',
              name: json['name']?.toString() ?? 'Wicchu member',
              userName: json['userName']?.toString() ?? '',
              avatarUrl: json['avatarUrl'] as String?,
            ),
          )
          .where((user) => user.id.isNotEmpty)
          .toList(growable: false),
      nextCursor: body['nextCursor']?.toString(),
    );
  }

  @override
  Future<UserFollowPage> listFollowers(String userId, {String? cursor}) =>
      _followPage(userId, 'followers', cursor: cursor);

  @override
  Future<UserFollowPage> listFollowingUsers(String userId, {String? cursor}) =>
      _followPage(userId, 'following', cursor: cursor);

  @override
  Future<UserFollowPage> listFollowRequests({String? cursor}) async {
    final uri = Uri(
      path: '/api/community/v1/me/follow-requests',
      queryParameters: cursor == null ? null : {'cursor': cursor},
    );
    final body = await _api.get(uri.toString());
    return UserFollowPage(
      users: _list(body, 'users')
          .map(
            (json) => UserFollowProfile(
              id: json['id']?.toString() ?? '',
              name: json['name']?.toString() ?? 'Wicchu member',
              userName: json['userName']?.toString() ?? '',
              avatarUrl: json['avatarUrl'] as String?,
            ),
          )
          .where((user) => user.id.isNotEmpty)
          .toList(growable: false),
      nextCursor: body['nextCursor']?.toString(),
    );
  }

  @override
  Future<void> respondToFollowRequest(
    String userId, {
    required bool accept,
  }) async {
    await _api.patch(
      '/api/community/v1/me/follow-requests/$userId',
      body: {'decision': accept ? 'accept' : 'reject'},
    );
  }

  @override
  Future<PeopleSearchPage> searchPeople({
    String query = '',
    String? cursor,
    int limit = 25,
    String? townId,
    double? latitude,
    double? longitude,
    double radiusKm = 10,
  }) async {
    final parameters = <String, String>{
      'query': query.trim(),
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (townId != null && townId.isNotEmpty) 'townId': townId,
      if (latitude != null) 'latitude': '$latitude',
      if (longitude != null) 'longitude': '$longitude',
      if (latitude != null && longitude != null) 'radiusKm': '$radiusKm',
    };
    final path = Uri(
      path: '/api/community/v1/users',
      queryParameters: parameters,
    ).toString();
    final body = await _api.get(path);
    return PeopleSearchPage(
      people: _list(body, 'people')
          .map(
            (json) => PeopleSearchResult(
              id: json['id']?.toString() ?? '',
              name: json['name']?.toString() ?? 'Wicchu member',
              userName: json['userName']?.toString() ?? '',
              avatarUrl: json['avatarUrl'] as String?,
              sharedCommunityCount:
                  (json['sharedCommunityCount'] as num?)?.toInt() ?? 0,
              distanceKm: (json['distanceKm'] as num?)?.toDouble(),
            ),
          )
          .where((person) => person.id.isNotEmpty)
          .toList(growable: false),
      nextCursor: body['nextCursor']?.toString(),
    );
  }

  @override
  Future<List<BlockedUser>> listBlockedUsers() async {
    final body = await _api.get('/api/community/v1/me/blocked-users?limit=100');
    return _array(body, 'items')
        .map(
          (json) => BlockedUser(
            userId: json['userId']?.toString() ?? '',
            name: json['name']?.toString() ?? 'Wicchu member',
            avatarUrl: json['avatarUrl'] as String?,
          ),
        )
        .where((item) => item.userId.isNotEmpty)
        .toList();
  }

  @override
  Future<void> blockUser(String userId) async {
    await _api.put('/api/community/v1/me/blocked-users/$userId');
  }

  @override
  Future<void> unblockUser(String userId) async {
    await _api.delete('/api/community/v1/me/blocked-users/$userId');
  }

  @override
  Future<List<DirectConversation>> listDirectConversations({
    String? pageId,
  }) async {
    final suffix = pageId == null
        ? ''
        : '?pageId=${Uri.encodeQueryComponent(pageId)}';
    final body = await _api.get(
      '/api/community/v1/messages/conversations$suffix',
    );
    return _list(
      body,
      'conversations',
    ).map(_directConversationFromJson).toList(growable: false);
  }

  @override
  Future<List<DirectConversation>> listMessageRequests({String? pageId}) async {
    final suffix = pageId == null
        ? '?requests=true'
        : '?requests=true&pageId=${Uri.encodeQueryComponent(pageId)}';
    final body = await _api.get(
      '/api/community/v1/messages/conversations$suffix',
    );
    return _list(
      body,
      'conversations',
    ).map(_directConversationFromJson).toList(growable: false);
  }

  @override
  Future<DirectConversation> startDirectConversation(String userId) async {
    final body = await _api.post(
      '/api/community/v1/messages/conversations',
      body: {'userId': userId},
    );
    return _directConversationFromJson(_object(body, 'conversation'));
  }

  @override
  Future<DirectConversation> startPageConversation(String pageId) async {
    final body = await _api.post(
      '/api/community/v1/messages/conversations',
      body: {'pageId': pageId},
    );
    return _directConversationFromJson(_object(body, 'conversation'));
  }

  @override
  Future<void> updateDirectConversationLabel(
    String conversationId,
    ConversationLabel label,
  ) async {
    await _api.patch(
      '/api/community/v1/messages/conversations/$conversationId/label',
      body: {'label': _conversationLabelValue(label)},
    );
  }

  @override
  Future<void> respondToMessageRequest(
    String conversationId, {
    required bool accept,
  }) async {
    await _api.patch(
      '/api/community/v1/messages/conversations/$conversationId/request',
      body: {'action': accept ? 'accept' : 'decline'},
    );
  }

  @override
  Future<DirectMessagePage> listDirectMessages(
    String conversationId, {
    String? before,
  }) async {
    final cursor = before == null
        ? ''
        : '&before=${Uri.encodeQueryComponent(before)}';
    final body = await _api.get(
      '/api/community/v1/messages/conversations/$conversationId?limit=50$cursor',
    );
    return DirectMessagePage(
      messages: _list(
        body,
        'messages',
      ).map(_directMessageFromJson).toList(growable: false),
      nextCursor: body['nextCursor']?.toString(),
    );
  }

  @override
  Future<void> markDirectConversationRead(String conversationId) async {
    await _api.patch(
      '/api/community/v1/messages/conversations/$conversationId/read',
    );
  }

  @override
  Future<DirectMessage> sendDirectMessage(
    String conversationId,
    String body,
  ) async {
    final response = await _api.post(
      '/api/community/v1/messages/conversations/$conversationId',
      body: {'body': body},
    );
    return _directMessageFromJson(_object(response, 'message'));
  }

  @override
  Future<void> deleteDirectMessage(
    String messageId, {
    required bool everyone,
  }) async {
    await _api.delete(
      '/api/community/v1/messages/$messageId?scope=${everyone ? 'everyone' : 'me'}',
    );
  }

  @override
  Future<void> deleteDirectConversation(String conversationId) async {
    await _api.delete(
      '/api/community/v1/messages/conversations/$conversationId',
    );
  }

  @override
  Future<MessagingPrivacy> getMessagingPrivacy() async {
    final body = await _api.get('/api/community/v1/messages/privacy');
    return _messagingPrivacy(body['messagingPrivacy']);
  }

  @override
  Future<MessagingPrivacy> updateMessagingPrivacy(
    MessagingPrivacy value,
  ) async {
    final body = await _api.patch(
      '/api/community/v1/messages/privacy',
      body: {'messagingPrivacy': _messagingPrivacyValue(value)},
    );
    return _messagingPrivacy(body['messagingPrivacy']);
  }

  static MessagingPrivacy _messagingPrivacy(Object? value) => switch (value) {
    'shared_communities' => MessagingPrivacy.sharedCommunities,
    'nobody' => MessagingPrivacy.nobody,
    _ => MessagingPrivacy.everyone,
  };

  static String _messagingPrivacyValue(MessagingPrivacy value) =>
      switch (value) {
        MessagingPrivacy.everyone => 'everyone',
        MessagingPrivacy.sharedCommunities => 'shared_communities',
        MessagingPrivacy.nobody => 'nobody',
      };

  @override
  Future<void> reportDirectMessage(
    String messageId,
    String reason, {
    required String category,
  }) async {
    await _api.post(
      '/api/community/v1/messages/$messageId/reports',
      body: {'reason': reason, 'category': category},
    );
  }

  static DirectConversation _directConversationFromJson(
    Map<String, dynamic> json,
  ) {
    final user = json['otherUser'] is Map<String, dynamic>
        ? json['otherUser'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return DirectConversation(
      id: json['id']?.toString() ?? '',
      otherUser: WicchuUser(
        id: user['id']?.toString() ?? '',
        name: user['name']?.toString() ?? 'Wicchu member',
        avatarUrl: user['avatarUrl'] as String?,
      ),
      lastMessagePreview: json['lastMessagePreview']?.toString() ?? '',
      lastMessageAt: _optionalDate(json['lastMessageAt']),
      lastMessageMine: json['lastMessageMine'] == true,
      lastMessageRemoved: json['lastMessageRemoved'] == true,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      requestStatus: switch (json['requestStatus']) {
        'pending' => MessageRequestStatus.pending,
        'declined' => MessageRequestStatus.declined,
        _ => MessageRequestStatus.accepted,
      },
      requestedByMe: json['requestedByMe'] == true,
      canSendMessage: json['canSendMessage'] != false,
      pageId: json['pageId']?.toString(),
      pageName: json['pageName']?.toString(),
      viewingAsPage: json['viewingAsPage'] == true,
      otherIsPage: json['otherIsPage'] == true,
      communityInbox: json['communityInbox'] == true,
      label: _conversationLabel(json['label']),
      isOnline: json['isOnline'] == true,
      lastActiveAt: _optionalDate(json['lastActiveAt']),
    );
  }

  static ConversationLabel _conversationLabel(Object? value) => switch (value) {
    'in_progress' => ConversationLabel.inProgress,
    'customer' => ConversationLabel.customer,
    'order' => ConversationLabel.order,
    'quote' => ConversationLabel.quote,
    'completed' => ConversationLabel.completed,
    _ => ConversationLabel.newConversation,
  };

  static String _conversationLabelValue(ConversationLabel value) =>
      switch (value) {
        ConversationLabel.newConversation => 'new',
        ConversationLabel.inProgress => 'in_progress',
        ConversationLabel.customer => 'customer',
        ConversationLabel.order => 'order',
        ConversationLabel.quote => 'quote',
        ConversationLabel.completed => 'completed',
      };

  static DirectMessage _directMessageFromJson(Map<String, dynamic> json) =>
      DirectMessage(
        id: json['id']?.toString() ?? '',
        conversationId: json['conversationId']?.toString() ?? '',
        senderId: json['senderId']?.toString() ?? '',
        recipientId: json['recipientId']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        createdAt:
            _optionalDate(json['createdAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        readAt: _optionalDate(json['readAt']),
        removedAt: _optionalDate(json['removedAt']),
        sentByMe: json['sentByMe'] == true,
      );

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

  @override
  Future<EditableMemberProfile> getEditableProfile() async {
    final body = await _api.get('/api/community/v1/me/profile');
    return _editableProfileFromJson(_object(body, 'profile'));
  }

  @override
  Future<bool> isUsernameAvailable(String userName) async {
    final uri = Uri(
      path: '/api/community/v1/me/profile/username-availability',
      queryParameters: {'userName': userName.trim()},
    );
    final body = await _api.get(uri.toString());
    return body['available'] == true;
  }

  @override
  Future<EditableMemberProfile> updateEditableProfile(
    EditableMemberProfile profile,
  ) async {
    final body = await _api.patch(
      '/api/community/v1/me/profile',
      body: {
        'name': profile.name,
        'userName': profile.userName,
        'shortDescription': profile.shortDescription,
        'bio': profile.bio,
        'location': profile.location,
        'accentColor': profile.accentColor,
        'neonBordersEnabled': profile.neonBordersEnabled,
        'neonBorderAnimation': profile.neonBorderAnimation.apiValue,
        'neonAnimationDurationSeconds': profile.neonAnimationDurationSeconds,
        'isPrivate': profile.isPrivate,
        'socialLinks': {
          'whatsapp': profile.socialLinks.whatsapp,
          'facebook': profile.socialLinks.facebook,
          'instagram': profile.socialLinks.instagram,
        },
      },
    );
    return _editableProfileFromJson(_object(body, 'profile'));
  }

  static EditableMemberProfile _editableProfileFromJson(
    Map<String, dynamic> json,
  ) => EditableMemberProfile(
    name: json['name']?.toString() ?? '',
    userName: json['userName']?.toString() ?? '',
    shortDescription: json['shortDescription']?.toString() ?? '',
    bio: json['bio']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
    accentColor: json['accentColor']?.toString() ?? 'teal',
    neonBordersEnabled: json['neonBordersEnabled'] == true,
    neonBorderAnimation: neonBorderAnimationFromApi(
      json['neonBorderAnimation'],
    ),
    neonAnimationDurationSeconds:
        (json['neonAnimationDurationSeconds'] as num?)?.toDouble() ?? 5,
    isPrivate: json['isPrivate'] == true,
    socialLinks: _socialLinksFromJson(json['socialLinks']),
  );

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
  Future<CategoryActivity> getCategoryActivity(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/category-activity',
    );
    final counts = <String, int>{};
    for (final item in _list(body, 'activity')) {
      final id = item['categoryId']?.toString();
      if (id != null) counts[id] = (item['unreadCount'] as num?)?.toInt() ?? 0;
    }
    return CategoryActivity(
      totalUnreadCount: (body['totalUnreadCount'] as num?)?.toInt() ?? 0,
      unreadByCategory: counts,
    );
  }

  @override
  Future<void> markCommunityPostsSeen(
    String communityId,
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return;
    await _api.post(
      '/api/community/v1/communities/$communityId/posts/seen',
      body: {'postIds': postIds},
    );
  }

  @override
  Future<ScopedNotificationPreferences>
  getCommunityContentNotificationPreferences(
    String communityId,
  ) async => _scopedPreferencesFromJson(
    await _api.get(
      '/api/community/v1/communities/$communityId/content-notification-preferences',
    ),
    defaults: const ScopedNotificationPreferences.communityDefaults(),
  );

  @override
  Future<ScopedNotificationPreferences>
  updateCommunityContentNotificationPreferences(
    String communityId,
    ScopedNotificationPreferences preferences,
  ) async => _scopedPreferencesFromJson(
    await _api.put(
      '/api/community/v1/communities/$communityId/content-notification-preferences',
      body: _scopedPreferencesToJson(preferences),
    ),
    defaults: const ScopedNotificationPreferences.communityDefaults(),
  );

  @override
  Future<ScopedNotificationPreferences> getPersonContentNotificationPreferences(
    String userId,
  ) async => _scopedPreferencesFromJson(
    await _api.get(
      '/api/community/v1/users/$userId/content-notification-preferences',
    ),
  );

  @override
  Future<ScopedNotificationPreferences>
  updatePersonContentNotificationPreferences(
    String userId,
    ScopedNotificationPreferences preferences,
  ) async => _scopedPreferencesFromJson(
    await _api.put(
      '/api/community/v1/users/$userId/content-notification-preferences',
      body: _scopedPreferencesToJson(preferences),
    ),
  );

  @override
  Future<void> registerDeviceToken(
    String token, {
    required String platform,
    String languageCode = 'en',
  }) async {
    await _api.post(
      '/api/community/v1/me/devices',
      body: {
        'token': token,
        'platform': platform,
        'languageCode': languageCode,
      },
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
  Future<List<Community>> listCommunities({String? query, String? townId}) {
    final parameters = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (townId != null && townId.isNotEmpty) 'townId': townId,
    };
    return _listCommunities(
      parameters.isEmpty ? '' : '?${Uri(queryParameters: parameters).query}',
    );
  }

  @override
  Future<Community> getCommunity(String communityId) async {
    final body = await _api.get('/api/community/v1/communities/$communityId');
    return _communityFromJson(_object(body, 'community'));
  }

  @override
  Future<List<Community>> listJoinedCommunities() =>
      _listCommunities('?joined=true');

  @override
  Future<List<Community>> listNearbyCommunities({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    String? excludeTownId,
  }) async {
    final uri = Uri(
      path: '/api/community/v1/communities/nearby',
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radiusKm': '$radiusKm',
        if (excludeTownId != null && excludeTownId.isNotEmpty)
          'excludeTownId': excludeTownId,
      },
    );
    final body = await _api.get(uri.toString());
    return _list(
      body,
      'communities',
    ).map(_communityFromJson).toList(growable: false);
  }

  @override
  Future<List<Community>> listLocalBusinesses({
    String? townId,
    String? query,
  }) async {
    final uri = Uri(
      path: '/api/community/v1/communities',
      queryParameters: {
        'type': 'public_profile',
        'profileCategories': 'local_business,organization',
        'limit': '100',
        if (townId != null && townId.isNotEmpty) 'townId': townId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final body = await _api.get(uri.toString());
    return _list(
      body,
      'communities',
    ).map(_communityFromJson).toList(growable: false);
  }

  @override
  Future<List<Community>> listNearbyBusinesses({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? query,
  }) async {
    final uri = Uri(
      path: '/api/community/v1/businesses/nearby',
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radiusKm': '$radiusKm',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
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
        'type': input.type == CommunityType.publicProfile
            ? 'public_profile'
            : 'community',
        if (input.type == CommunityType.publicProfile &&
            input.profileCategory != null)
          'profileCategory': input.profileCategory!.apiValue,
        'shortDescription': input.shortDescription,
        'description': input.description,
        'subject': input.subject,
        'scope': input.scope.name,
        if (input.town != null) 'townId': input.town!.id,
        'visibility': input.visibility.name,
        'categoryNames': input.categoryNames,
        if (input.categories.isNotEmpty)
          'categories': input.categories
              .map((item) => {'key': item.key, 'name': item.name})
              .toList(),
        'approvalRequired': input.approvalRequired,
        'rules': input.rules
            .map(
              (rule) => {'title': rule.title, 'description': rule.description},
            )
            .toList(),
      },
    );
    final json = _object(body, 'community');
    return _communityFromJson({
      ...json,
      'town': input.town == null
          ? {'id': '', 'name': 'Everywhere', 'countryCode': ''}
          : _townToJson(input.town!),
      'myRole': 'owner',
      'memberCount': 1,
    });
  }

  @override
  Future<CategorySuggestions> getCategorySuggestions({
    required CommunityType spaceType,
    required String subject,
    required String language,
  }) async {
    final body = await _api.post(
      '/api/community/v1/communities/category-suggestions',
      body: {
        'spaceType': spaceType == CommunityType.community
            ? 'community'
            : 'public_profile',
        'subject': subject,
        'language': language,
      },
    );
    return CategorySuggestions(
      template: body['template']?.toString() ?? 'default',
      editable: body['editable'] != false,
      categories: _list(body, 'categories')
          .map(
            (item) => CategorySuggestion(
              key: item['key']?.toString(),
              name: item['name']?.toString() ?? '',
            ),
          )
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false),
    );
  }

  @override
  Future<void> joinCommunity(String communityId) async {
    await _api.post('/api/community/v1/communities/$communityId/join');
    unawaited(AnalyticsService.instance.log('community_joined'));
  }

  @override
  Future<CommunityHelpfulness> getCommunityHelpfulness(
    String communityId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/feedback',
    );
    return _helpfulnessFromJson(_object(body, 'feedback'));
  }

  @override
  Future<CommunityHelpfulness> setCommunityHelpfulness(
    String communityId, {
    required bool helpful,
    String? locallyRelevant,
    String? safeParticipation,
    String? wellOrganized,
    bool? recommend,
  }) async {
    final body = await _api.put(
      '/api/community/v1/communities/$communityId/feedback',
      body: {
        'helpful': helpful,
        'locallyRelevant': ?locallyRelevant,
        'safeParticipation': ?safeParticipation,
        'wellOrganized': ?wellOrganized,
        'recommend': ?recommend,
      },
    );
    return _helpfulnessFromJson(_object(body, 'feedback'));
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
  Future<CommunityInvitation> createCommunityInvitationLink(
    String communityId,
  ) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/invitations/link',
    );
    return _invitationFromJson(
      _object(body, 'invitation'),
      invitationUrl: body['invitationUrl']?.toString(),
    );
  }

  @override
  Future<CommunityInvitation> getCommunityInvitationLink(String token) async {
    final body = await _api.get(
      '/api/community/v1/invitations/link/${Uri.encodeComponent(token)}',
    );
    return _invitationFromJson(_object(body, 'invitation'));
  }

  @override
  Future<void> respondToCommunityInvitationLink(
    String token, {
    required bool accept,
  }) async {
    await _api.post(
      '/api/community/v1/invitations/link/${Uri.encodeComponent(token)}/${accept ? 'accept' : 'decline'}',
    );
  }

  @override
  Future<List<CommunityInvitation>> listCommunityInvitations(
    String communityId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/invitations',
    );
    return _list(
      body,
      'invitations',
    ).map(_invitationFromJson).toList(growable: false);
  }

  @override
  Future<List<CommunityInvitation>> listMyCommunityInvitations() async {
    final body = await _api.get('/api/community/v1/me/invitations');
    return _list(
      body,
      'invitations',
    ).map(_invitationFromJson).toList(growable: false);
  }

  @override
  Future<void> respondToCommunityInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    await _api.post(
      '/api/community/v1/me/invitations/$invitationId/${accept ? 'accept' : 'decline'}',
    );
  }

  @override
  Future<void> revokeCommunityInvitation(
    String communityId,
    String invitationId,
  ) async {
    await _api.delete(
      '/api/community/v1/communities/$communityId/invitations/$invitationId',
    );
  }

  @override
  Future<CommunityInvitation> resendCommunityInvitation(
    String communityId,
    String invitationId,
  ) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/invitations/$invitationId/resend',
    );
    return _invitationFromJson(
      _object(body, 'invitation'),
      invitationUrl: body['invitationUrl']?.toString(),
    );
  }

  @override
  Future<List<CommunityAuditEntry>> listCommunityAuditHistory(
    String communityId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/moderation-history',
    );
    return _list(body, 'actions')
        .map((json) {
          final actor = json['actor'] is Map<String, dynamic>
              ? json['actor'] as Map<String, dynamic>
              : const <String, dynamic>{};
          final target = json['targetUser'] is Map<String, dynamic>
              ? json['targetUser'] as Map<String, dynamic>
              : const <String, dynamic>{};
          final details = json['details'] is Map<String, dynamic>
              ? json['details'] as Map<String, dynamic>
              : const <String, dynamic>{};
          return CommunityAuditEntry(
            id: _id(json),
            action: json['action']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.now(),
            actorName: actor['name']?.toString() ?? 'Wicchu administrator',
            targetName: target['name']?.toString(),
            reason: json['reason']?.toString() ?? '',
            details: details,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> createOwnershipTransfer(
    String communityId,
    String targetUserId,
  ) async {
    await _api.post(
      '/api/community/v1/communities/$communityId/ownership-transfers',
      body: {'targetUserId': targetUserId},
    );
  }

  @override
  Future<void> createAdminInvitation(
    String communityId,
    String targetUserId,
  ) async {
    await _api.post(
      '/api/community/v1/communities/$communityId/admin-invitations',
      body: {'targetUserId': targetUserId},
    );
  }

  @override
  Future<void> stepDownCommunityRole(String communityId) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/membership/step-down',
    );
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
      body: {'title': title, 'description': description, 'position': position},
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
        'title': ?title,
        'description': ?description,
        'position': ?position,
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
  Future<bool> getAdminAnonymity(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/membership/anonymity',
    );
    return body['anonymousInCommunity'] == true;
  }

  @override
  Future<bool> updateAdminAnonymity(
    String communityId, {
    required bool anonymousInCommunity,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/communities/$communityId/membership/anonymity',
      body: {'anonymousInCommunity': anonymousInCommunity},
    );
    return body['anonymousInCommunity'] == true;
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
  Future<List<String>> getCategoryOrder(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/category-order',
    );
    return (body['order'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
  }

  @override
  Future<List<String>> updateCategoryOrder(
    String communityId,
    List<String> order,
  ) async {
    final body = await _api.put(
      '/api/community/v1/communities/$communityId/category-order',
      body: {'order': order},
    );
    return (body['order'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
  }

  @override
  Future<List<String>> resetCategoryOrder(String communityId) async {
    final body = await _api.delete(
      '/api/community/v1/communities/$communityId/category-order',
    );
    return (body['order'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
  }

  @override
  Future<CommunityCategory> createCategory(
    String communityId, {
    required String name,
    String description = '',
    String? icon,
  }) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/categories',
      body: {'name': name, 'description': description, 'icon': ?icon},
    );
    return _categoryFromJson(_object(body, 'category'));
  }

  @override
  Future<CommunityCategory> updateCategory(
    String communityId,
    CommunityCategory category, {
    required String name,
    required String description,
    String? icon,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/communities/$communityId/categories/${category.id}',
      body: {'name': name, 'description': description, 'icon': ?icon},
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
  Future<List<CommunityCategory>> reorderCategories(
    String communityId,
    List<String> categoryIds,
  ) async {
    final body = await _api.put(
      '/api/community/v1/communities/$communityId/categories/order',
      body: {'categoryIds': categoryIds},
    );
    return _list(
      body,
      'categories',
    ).map(_categoryFromJson).toList(growable: false);
  }

  @override
  Future<List<CommunityMember>> listMembers(
    String communityId, {
    bool includeInactive = false,
  }) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/members${includeInactive ? '?includeInactive=true' : ''}',
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
            isAnonymous: json['isAnonymous'] == true,
            banPublicReason: json['banPublicReason']?.toString(),
            banInternalNote: json['banInternalNote']?.toString(),
            bannedAt: _optionalDate(json['bannedAt']),
            banExpiresAt: _optionalDate(json['banExpiresAt']),
            pageInboxAccess: json['pageInboxAccess'] == true,
            canManageOrders:
                (json['pagePermissions'] as Map<String, dynamic>?)?['orders'] ==
                true,
            canManageServices:
                (json['pagePermissions']
                    as Map<String, dynamic>?)?['services'] ==
                true,
            canViewPageAnalytics:
                (json['pagePermissions']
                    as Map<String, dynamic>?)?['analytics'] ==
                true,
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
  Future<void> setPageInboxAccess(
    String communityId,
    String userId, {
    required bool enabled,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/members/$userId/page-inbox',
      body: {'pageInboxAccess': enabled},
    );
  }

  @override
  Future<void> setPagePermissions(
    String communityId,
    String userId, {
    required bool messages,
    required bool orders,
    required bool services,
    required bool analytics,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/members/$userId/page-permissions',
      body: {
        'messages': messages,
        'orders': orders,
        'services': services,
        'analytics': analytics,
      },
    );
  }

  @override
  Future<void> setMemberAccess(
    String communityId,
    String userId, {
    required String action,
    String? reason,
    String? internalNote,
    DateTime? expiresAt,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/admin/members/$userId/access',
      body: {
        'action': action,
        'reason': ?reason,
        'internalNote': ?internalNote,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Community> updateCommunity(
    Community community, {
    required Town town,
    required String name,
    String? shortDescription,
    required String description,
    required CommunityVisibility visibility,
    required bool approvalRequired,
    bool? membersListVisible,
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
    bool? neonBordersEnabled,
    NeonBorderAnimation? neonBorderAnimation,
    double? neonAnimationDurationSeconds,
    bool? headerBorderEnabled,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/communities/${community.id}',
      body: {
        'townId': town.id,
        'name': name,
        'shortDescription': shortDescription ?? community.shortDescription,
        'description': description,
        'visibility': visibility.name,
        if (community.isPublicProfile)
          'published': published ?? community.published,
        'accentColor': accentColor ?? community.accentColor,
        'neonBordersEnabled':
            neonBordersEnabled ?? community.neonBordersEnabled,
        'neonBorderAnimation':
            (neonBorderAnimation ?? community.neonBorderAnimation).apiValue,
        'neonAnimationDurationSeconds':
            neonAnimationDurationSeconds ??
            community.neonAnimationDurationSeconds,
        if (headerBorderEnabled != null || community.headerBorderEnabled)
          'headerBorderEnabled':
              headerBorderEnabled ?? community.headerBorderEnabled,
        'approvalRequired': approvalRequired,
        'membersListVisible': ?membersListVisible,
        'showWeather': showWeather,
        if (community.isPublicProfile && profileCategory != null)
          'profileCategory': profileCategory.apiValue,
        if (community.isPublicProfile &&
            profileCategory == ProfileCategory.localBusiness)
          'businessServices': businessServices
              .map((service) => service.apiValue)
              .toList(),
        'links': links
            .map((link) => {'label': link.label, 'url': link.url})
            .toList(),
        if (community.isPublicProfile)
          'businessLocation': businessLocation == null
              ? null
              : {
                  'address': businessLocation.address,
                  'latitude': businessLocation.latitude,
                  'longitude': businessLocation.longitude,
                  'showExactAddress': businessLocation.showExactAddress,
                },
        if (businessHours != null)
          'businessHours': businessHours
              .map(
                (hours) => {
                  'day': hours.day,
                  'open': hours.open,
                  'close': hours.close,
                  'closed': hours.closed,
                },
              )
              .toList(),
        if (businessFulfillmentOptions != null)
          'businessFulfillmentOptions': businessFulfillmentOptions
              .map((option) => option.apiValue)
              .toList(),
        if (businessContact != null)
          'businessContact': {
            'phone': businessContact.phone,
            'whatsapp': businessContact.whatsapp,
          },
        'imageBlobName': ?imageBlobName,
        'coverImageBlobName': ?coverImageBlobName,
      },
    );
    final responseCommunity = _object(body, 'community');
    return _communityFromJson({
      ...responseCommunity,
      if (responseCommunity['town'] == null) 'town': _townToJson(town),
      'memberCount': community.memberCount,
      'myRole': community.myRole?.name,
      'membersListVisible':
          responseCommunity['membersListVisible'] ??
          membersListVisible ??
          community.membersListVisible,
    });
  }

  @override
  Future<CommunityWeather?> getCommunityWeather(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/weather',
    );
    if (body['enabled'] != true) return null;
    final weather = _object(body, 'weather');
    return CommunityWeather(
      townName: body['townName']?.toString() ?? '',
      temperature: (weather['temperature'] as num?)?.toDouble() ?? 0,
      apparentTemperature:
          (weather['apparentTemperature'] as num?)?.toDouble() ?? 0,
      minTemperature: (weather['minTemperature'] as num?)?.toDouble() ?? 0,
      maxTemperature: (weather['maxTemperature'] as num?)?.toDouble() ?? 0,
      weatherCode: (weather['weatherCode'] as num?)?.toInt() ?? 0,
      description: weather['description']?.toString() ?? '',
      isDay: weather['isDay'] == true,
      observedAt: DateTime.tryParse(weather['observedAt']?.toString() ?? ''),
      provider: weather['provider']?.toString() ?? 'Open-Meteo',
    );
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
    try {
      final body = await _api.get(uri.toString());
      return _list(body, 'posts').map(_postFromJson).toList(growable: false);
    } catch (error) {
      if (kDebugMode) {
        // Record the failure category without credentials or response contents.
        debugPrint(
          'Page feed load failed: ${uri.path}; '
          'type=${error.runtimeType}; '
          'status=${error is ApiException ? error.statusCode : null}',
        );
      }
      rethrow;
    }
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
  Future<List<CommunityPost>> listTodayMenus(
    String townId, {
    String? query,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final body = await _api.get(
      '/api/community/v1/towns/$townId/today-menus$suffix',
    );
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<List<CommunityPost>> listLocalBusinessPosts(
    String townId, {
    String? query,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final body = await _api.get(
      '/api/community/v1/towns/$townId/business-posts$suffix',
    );
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<List<CommunityPost>> listBusinessPosts(
    List<String> businessIds, {
    String? query,
  }) async {
    if (businessIds.isEmpty) return const [];
    final uri = Uri(
      path: '/api/community/v1/businesses/posts',
      queryParameters: {
        'businessIds': businessIds.take(100).join(','),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final body = await _api.get(uri.toString());
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<BusinessCatalog> getBusinessCatalog(
    String businessId, {
    bool manage = false,
  }) async {
    final body = await _api.get(
      '/api/community/v1/businesses/$businessId/${manage ? 'manage/catalog' : 'catalog'}',
    );
    return _businessCatalogFromJson(_object(body, 'catalog'));
  }

  @override
  Future<void> setBusinessAcceptingOrders(
    String businessId, {
    required bool accepting,
  }) async {
    await _api.patch(
      '/api/community/v1/businesses/$businessId/order-settings',
      body: {'acceptingOrders': accepting},
    );
  }

  @override
  Future<BusinessCatalogCategory> createBusinessCatalogCategory(
    String businessId,
    String name,
  ) async {
    final body = await _api.post(
      '/api/community/v1/businesses/$businessId/catalog/categories',
      body: {'name': name},
    );
    return _businessCatalogCategoryFromJson(_object(body, 'category'));
  }

  @override
  Future<void> deleteBusinessCatalogCategory(
    String businessId,
    String categoryId,
  ) async {
    await _api.delete(
      '/api/community/v1/businesses/$businessId/catalog/categories/$categoryId',
    );
  }

  Map<String, Object?> _businessProductBody(BusinessProductInput input) => {
    'categoryId': input.categoryId,
    'kind': input.kind == BusinessProductKind.dailyMenu
        ? 'daily_menu'
        : 'product',
    'name': input.name,
    'description': input.description,
    'priceCents': input.priceCents,
    'available': input.available,
    'quantityAvailable': input.quantityAvailable,
    'variants': input.variants
        .map(
          (variant) => {
            if (variant.id != null) 'id': variant.id,
            'name': variant.name,
            'sku': variant.sku,
            'priceCents': variant.priceCents,
            'available': variant.available,
            'quantityAvailable': variant.quantityAvailable,
            'attributes': variant.attributes.entries
                .map((entry) => {'name': entry.key, 'value': entry.value})
                .toList(),
          },
        )
        .toList(),
    'expiresAt': input.expiresAt?.toUtc().toIso8601String(),
    'position': input.position,
    if (input.image != null) 'imageBlobName': input.image!.blobName,
    if (input.image != null) 'imageUrl': input.image!.url,
  };

  @override
  Future<BusinessProduct> createBusinessProduct(
    String businessId,
    BusinessProductInput input,
  ) async {
    final body = await _api.post(
      '/api/community/v1/businesses/$businessId/catalog/products',
      body: _businessProductBody(input),
    );
    return _businessProductFromJson(_object(body, 'product'));
  }

  @override
  Future<BusinessProduct> updateBusinessProduct(
    String businessId,
    String productId,
    BusinessProductInput input,
  ) async {
    final body = await _api.patch(
      '/api/community/v1/businesses/$businessId/catalog/products/$productId',
      body: _businessProductBody(input),
    );
    return _businessProductFromJson(_object(body, 'product'));
  }

  @override
  Future<void> deleteBusinessProduct(
    String businessId,
    String productId,
  ) async {
    await _api.delete(
      '/api/community/v1/businesses/$businessId/catalog/products/$productId',
    );
  }

  @override
  Future<BusinessOrder> createBusinessOrder(
    String businessId,
    BusinessOrderInput input,
  ) async {
    final body = await _api.post(
      '/api/community/v1/businesses/$businessId/orders',
      body: {
        'fulfillmentMethod': input.fulfillmentMethod.apiValue,
        'deliveryAddress': input.deliveryAddress,
        'customerPhone': input.customerPhone,
        'notes': input.notes,
        'items': input.lines.isNotEmpty
            ? input.lines
                  .where((line) => line.quantity > 0)
                  .map(
                    (line) => {
                      'productId': line.productId,
                      if (line.variantId != null) 'variantId': line.variantId,
                      'quantity': line.quantity,
                    },
                  )
                  .toList()
            : input.quantities.entries
                  .where((entry) => entry.value > 0)
                  .map(
                    (entry) => {
                      'productId': entry.key,
                      'quantity': entry.value,
                    },
                  )
                  .toList(),
      },
    );
    return _businessOrderFromJson(_object(body, 'order'));
  }

  @override
  Future<List<BusinessOrder>> listMyBusinessOrders() async {
    final body = await _api.get('/api/community/v1/me/business-orders');
    return _list(
      body,
      'orders',
    ).map(_businessOrderFromJson).toList(growable: false);
  }

  @override
  Future<List<BusinessOrder>> listManagedBusinessOrders(
    String businessId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/businesses/$businessId/orders',
    );
    return _list(
      body,
      'orders',
    ).map(_businessOrderFromJson).toList(growable: false);
  }

  @override
  Future<BusinessOrder> updateBusinessOrderStatus(
    String orderId,
    BusinessOrderStatus status, {
    String reason = '',
  }) async {
    final body = await _api.patch(
      '/api/community/v1/business-orders/$orderId/status',
      body: {'status': status.name, 'reason': reason},
    );
    return _businessOrderFromJson(_object(body, 'order'));
  }

  @override
  Future<BusinessOrder> cancelBusinessOrder(String orderId) async {
    final body = await _api.post(
      '/api/community/v1/business-orders/$orderId/cancel',
    );
    return _businessOrderFromJson(_object(body, 'order'));
  }

  @override
  Future<BusinessRequestSettings> getBusinessRequestSettings(
    String businessId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/businesses/$businessId/request-settings',
    );
    return _businessRequestSettingsFromJson(_object(body, 'settings'));
  }

  @override
  Future<BusinessRequestSettings> updateBusinessRequestSettings(
    String businessId, {
    required bool acceptingRequests,
    required List<BusinessRequestType> capabilities,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/businesses/$businessId/request-settings',
      body: {
        'acceptingRequests': acceptingRequests,
        'capabilities': capabilities.map((type) => type.apiValue).toList(),
      },
    );
    return _businessRequestSettingsFromJson(_object(body, 'settings'));
  }

  @override
  Future<BusinessRequest> createBusinessRequest(
    String businessId,
    BusinessRequestInput input,
  ) async {
    final body = await _api.post(
      '/api/community/v1/businesses/$businessId/requests',
      body: {
        'type': input.type.apiValue,
        'serviceName': input.serviceName,
        'description': input.description,
        'contactPhone': input.contactPhone,
        'location': input.location,
        'destination': input.destination,
        'preferredAt': input.preferredAt?.toUtc().toIso8601String(),
        'attachmentBlobNames': input.attachmentBlobNames,
      },
    );
    return _businessRequestFromJson(_object(body, 'request'));
  }

  @override
  Future<List<BusinessRequest>> listMyBusinessRequests() async {
    final body = await _api.get('/api/community/v1/me/business-requests');
    return _list(
      body,
      'requests',
    ).map(_businessRequestFromJson).toList(growable: false);
  }

  @override
  Future<List<BusinessRequest>> listManagedBusinessRequests(
    String businessId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/businesses/$businessId/requests',
    );
    return _list(
      body,
      'requests',
    ).map(_businessRequestFromJson).toList(growable: false);
  }

  @override
  Future<BusinessRequest> updateBusinessRequestStatus(
    String requestId,
    BusinessRequestStatus status, {
    String message = '',
    DateTime? scheduledAt,
    int? quotedPriceCents,
  }) async {
    final body = await _api.patch(
      '/api/community/v1/business-requests/$requestId/status',
      body: {
        'status': status.apiValue,
        'message': message,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        'quotedPriceCents': quotedPriceCents,
      },
    );
    return _businessRequestFromJson(_object(body, 'request'));
  }

  @override
  Future<BusinessRequest> cancelBusinessRequest(String requestId) async {
    final body = await _api.post(
      '/api/community/v1/business-requests/$requestId/cancel',
    );
    return _businessRequestFromJson(_object(body, 'request'));
  }

  @override
  Future<CommunityPost> getPost(String postId) async {
    final body = await _api.get('/api/community/v1/posts/$postId');
    return _postFromJson(_object(body, 'post'));
  }

  @override
  Future<PostTranslation> translatePost(
    String postId, {
    required String targetLanguage,
  }) async {
    final body = await _api.post(
      '/api/community/v1/posts/$postId/translation',
      body: {'targetLanguage': targetLanguage},
    );
    final json = _object(body, 'translation');
    return PostTranslation(
      postId: json['postId']?.toString() ?? postId,
      targetLanguage: json['targetLanguage']?.toString() ?? targetLanguage,
      sourceLanguage: json['sourceLanguage']?.toString() ?? '',
      translatedText: json['translatedText']?.toString() ?? '',
      cached: json['cached'] as bool? ?? false,
    );
  }

  @override
  Future<CommunityAboutTranslation> translateCommunityAbout(
    String communityId, {
    String targetLanguage = 'auto',
  }) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/about-translation',
      body: {'targetLanguage': targetLanguage},
    );
    final json = _object(body, 'translation');
    return CommunityAboutTranslation(
      communityId: json['communityId']?.toString() ?? communityId,
      targetLanguage: json['targetLanguage']?.toString() ?? targetLanguage,
      sourceLanguage: json['sourceLanguage']?.toString() ?? '',
      translatedShortDescription:
          json['translatedShortDescription']?.toString() ?? '',
      translatedDescription: json['translatedDescription']?.toString() ?? '',
      cached: json['cached'] as bool? ?? false,
    );
  }

  @override
  Future<List<LocalNewsSource>> listLocalNewsSources() async {
    final body = await _api.get('/api/community/v1/news/sources');
    return _list(body, 'sources')
        .map(
          (json) => LocalNewsSource(
            id: json['_id']?.toString() ?? '',
            name: json['name']?.toString() ?? '',
            type: json['type']?.toString() ?? 'rss',
            siteUrl: json['siteUrl']?.toString() ?? '',
            trusted: json['trusted'] == true,
            authorizedForAutoPublish: json['authorizedForAutoPublish'] == true,
          ),
        )
        .where((source) => source.id.isNotEmpty)
        .toList(growable: false);
  }

  LocalNewsLastRun? _localNewsRun(Map<String, dynamic>? json) {
    final finishedAt = _optionalDate(json?['finishedAt']);
    if (json == null || finishedAt == null) return null;
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    final reason = json['errorReason']?.toString();
    return LocalNewsLastRun(
      status: json['status']?.toString() ?? 'success',
      finishedAt: finishedAt,
      trigger: json['trigger']?.toString() ?? 'manual',
      errorReason: reason == null || reason.isEmpty ? null : reason,
      processed: count('processed'),
      pendingApproval: count('pendingApproval'),
      published: count('published'),
      skipped: count('skipped'),
      errors: count('errors'),
      sourceErrors: count('sourceErrors'),
    );
  }

  LocalNewsAccessApplication? _localNewsApplication(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return LocalNewsAccessApplication(
      id: id,
      status: value['status']?.toString() ?? 'pending',
      requestedAt:
          _optionalDate(value['requestedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      message: value['message']?.toString() ?? '',
      reviewNote: value['reviewNote']?.toString() ?? '',
      reviewedAt: _optionalDate(value['reviewedAt']),
    );
  }

  LocalNewsSettings _localNewsSettings(
    Map<String, dynamic> json, {
    Map<String, dynamic>? limits,
    List<dynamic>? plans,
    Map<String, dynamic>? body,
  }) {
    final tier = json['subscriptionTier']?.toString() ?? 'free';
    int count(Map<String, dynamic>? map, String key, [int fallback = 0]) =>
        (map?[key] as num?)?.toInt() ?? fallback;
    final accessJson = body?['access'] is Map<String, dynamic>
        ? body!['access'] as Map<String, dynamic>
        : null;
    final usageJson = body?['usage'] is Map<String, dynamic>
        ? body!['usage'] as Map<String, dynamic>
        : null;
    final runJson = body?['lastRun'] is Map<String, dynamic>
        ? body!['lastRun'] as Map<String, dynamic>
        : null;
    final access = accessJson == null
        ? null
        : LocalNewsAccess(
            entitled: accessJson['entitled'] == true,
            source: accessJson['source']?.toString() ?? 'none',
            tier: accessJson['tier']?.toString() ?? tier,
            monthlyLimit: count(accessJson, 'monthlyLimit'),
            dailyLimit: count(accessJson, 'dailyLimit', 1),
          );
    final dashboardJson = body?['dashboard'] is Map<String, dynamic>
        ? body!['dashboard'] as Map<String, dynamic>
        : null;
    return LocalNewsSettings(
      access: access,
      usage: LocalNewsUsage(
        month: usageJson?['month']?.toString() ?? '',
        monthlyUsed: count(usageJson, 'monthlyUsed'),
        monthlyLimit: count(usageJson, 'monthlyLimit'),
        todayUsed: count(usageJson, 'todayUsed'),
        dailyLimit: count(usageJson, 'dailyLimit', 1),
      ),
      lastRun: _localNewsRun(runJson),
      dashboard: dashboardJson == null
          ? null
          : LocalNewsDashboard(
              status: dashboardJson['status']?.toString() ?? 'scheduled',
              reason: dashboardJson['reason']?.toString(),
              enabled: dashboardJson['enabled'] == true,
              collecting: dashboardJson['collecting'] == true,
              approvalMode:
                  dashboardJson['approvalMode']?.toString() ?? 'manual',
              nextCollectionAt: _optionalDate(
                dashboardJson['nextCollectionAt'],
              ),
              scheduleUnavailableReason: dashboardJson['scheduleUnavailableReason']
                  ?.toString(),
              schedulerIntervalMinutes:
                  (dashboardJson['schedulerIntervalMinutes'] as num?)?.toInt(),
              timezone: dashboardJson['timezone']?.toString() ?? 'UTC',
              quotaResetsAt:
                  _optionalDate(dashboardJson['quotaResetsAt']) ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              pendingApproval: count(dashboardJson, 'pendingApproval'),
              todayUsed: count(dashboardJson, 'todayUsed'),
              publishedToday: count(dashboardJson, 'publishedToday'),
              dailyLimit: count(dashboardJson, 'dailyLimit', 1),
              monthlyUsed: count(dashboardJson, 'monthlyUsed'),
              monthlyLimit: count(dashboardJson, 'monthlyLimit'),
              lastRun: _localNewsRun(
                dashboardJson['lastRun'] is Map<String, dynamic>
                    ? dashboardJson['lastRun'] as Map<String, dynamic>
                    : null,
              ),
            ),
      application: _localNewsApplication(body?['application']),
      enabled: json['enabled'] == true,
      sourceIds: (json['sourceIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      categoryIds: (json['categoryIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      language: json['language']?.toString() ?? 'es',
      approvalMode: json['approvalMode']?.toString() ?? 'manual',
      subscriptionTier: tier,
      monthlyLimit:
          access?.monthlyLimit ?? (limits?[tier] as num?)?.toInt() ?? 0,
      tierLimits: {
        for (final entry in (limits ?? const <String, dynamic>{}).entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      },
      plans: (plans ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (plan) => LocalNewsPlan(
              tier: plan['tier']?.toString() ?? '',
              priceEur: (plan['priceEur'] as num?)?.toDouble() ?? 0,
              priceUsd: (plan['priceUsd'] as num?)?.toDouble() ?? 0,
            ),
          )
          .where((plan) => plan.tier.isNotEmpty)
          .toList(growable: false),
    );
  }

  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/news-settings',
    );
    return _localNewsSettings(
      _object(body, 'settings'),
      limits: body['tierLimits'] is Map<String, dynamic>
          ? body['tierLimits'] as Map<String, dynamic>
          : null,
      plans: body['plans'] as List?,
      body: body,
    );
  }

  @override
  Future<LocalNewsSettings> updateLocalNewsSettings(
    String communityId, {
    required bool enabled,
    required List<String> sourceIds,
    required List<String> categoryIds,
    required String language,
    required String approvalMode,
  }) async {
    await _api.put(
      '/api/community/v1/communities/$communityId/admin/news-settings',
      body: {
        'enabled': enabled,
        'sourceIds': sourceIds,
        'categoryIds': categoryIds,
        'language': language,
        'approvalMode': approvalMode,
      },
    );
    return getLocalNewsSettings(communityId);
  }

  @override
  Future<List<LocalNewsArticle>> listLocalNewsArticles(
    String communityId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/news-articles',
    );
    return _list(body, 'articles')
        .map(
          (json) => LocalNewsArticle(
            id: json['_id']?.toString() ?? '',
            title: json['title']?.toString() ?? '',
            status: json['status']?.toString() ?? 'collected',
            createdAt:
                _optionalDate(json['createdAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            sourceUrl: json['sourceUrl']?.toString() ?? '',
            skipReason: json['skipReason']?.toString() ?? '',
            errorCode: json['errorCode']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<LocalNewsAccessApplication> submitLocalNewsAccessApplication(
    String communityId, {
    String message = '',
  }) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/admin/news-access-application',
      body: {'message': message},
    );
    final application = _localNewsApplication(body['application']);
    if (application == null) throw const FormatException('Missing application');
    return application;
  }

  @override
  Future<LocalNewsAccessApplication> cancelLocalNewsAccessApplication(
    String communityId,
  ) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/admin/news-access-application/cancel',
    );
    final application = _localNewsApplication(body['application']);
    if (application == null) throw const FormatException('Missing application');
    return application;
  }

  @override
  Future<LocalNewsRunResult> runLocalNewsNow(String communityId) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/admin/news-collect',
    );
    int count(String key) => (body[key] as num?)?.toInt() ?? 0;
    return LocalNewsRunResult(
      collected: count('collected'),
      processed: count('processed'),
      pendingApproval: count('pendingApproval'),
      published: count('published'),
      skipped: count('skipped'),
      errors: count('errors'),
    );
  }

  @override
  Future<PostTranslation> translateComment(
    String commentId, {
    String targetLanguage = 'auto',
  }) async {
    final body = await _api.post(
      '/api/community/v1/comments/$commentId/translation',
      body: {'targetLanguage': targetLanguage},
    );
    final json = _object(body, 'translation');
    return PostTranslation(
      postId: json['commentId']?.toString() ?? commentId,
      targetLanguage: json['targetLanguage']?.toString() ?? targetLanguage,
      sourceLanguage: json['sourceLanguage']?.toString() ?? '',
      translatedText: json['translatedText']?.toString() ?? '',
      cached: json['cached'] as bool? ?? false,
    );
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
  Future<PostShareKit> getPostShareKit(String postId) async {
    final body = await _api.get('/api/community/v1/posts/$postId/share-kit');
    final kit = _object(body, 'shareKit');
    final targets = _object(kit, 'targets');
    final images = _object(kit, 'images');
    return PostShareKit(
      canonicalUrl: kit['canonicalUrl']?.toString() ?? '',
      message: kit['message']?.toString() ?? '',
      whatsappUrl: targets['whatsapp']?.toString() ?? '',
      facebookUrl: targets['facebook']?.toString() ?? '',
      instagramFeedImageUrl: images['instagramFeed']?.toString() ?? '',
      instagramStoryImageUrl: images['instagramStory']?.toString() ?? '',
    );
  }

  @override
  Future<void> recordPostShare(String postId) async {
    await _api.post('/api/community/v1/posts/$postId/share');
    unawaited(AnalyticsService.instance.log('post_shared'));
  }

  @override
  Future<void> recordBusinessPostEngagement(
    String postId, {
    required String action,
  }) async {
    await _api.post(
      '/api/community/v1/posts/$postId/business-engagement',
      body: {'action': action},
    );
    unawaited(
      AnalyticsService.instance.log(
        action == 'contact'
            ? 'business_contact_clicked'
            : 'business_content_viewed',
      ),
    );
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
        'mentionedUserIds': input.mentionedUserIds,
        'anonymousAsAdmin': input.anonymousAsAdmin,
        'anonymousAsMember': input.anonymousAsMember,
        'importantAnnouncement': input.importantAnnouncement,
        if (input.todayMenu case final menu?)
          'businessFeature': {
            'type': 'today_menu',
            'dishes': menu.dishes
                .map(
                  (dish) => {
                    'name': dish.name,
                    'price': dish.price,
                    'available': dish.available,
                  },
                )
                .toList(),
            'fulfillmentOptions': menu.fulfillmentOptions
                .map((option) => option.apiValue)
                .toList(),
            'expiresAt': menu.expiresAt.toUtc().toIso8601String(),
          },
        if (input.businessFeature case final feature?)
          'businessFeature': {
            'type': feature.type.apiValue,
            'title': feature.title,
            'price': feature.price,
            'available': feature.available,
            'fulfillmentOptions': feature.fulfillmentOptions
                .map((option) => option.apiValue)
                .toList(),
            if (feature.expiresAt != null)
              'expiresAt': feature.expiresAt!.toUtc().toIso8601String(),
            'routeFrom': feature.routeFrom,
            'routeTo': feature.routeTo,
            if (feature.departureAt != null)
              'departureAt': feature.departureAt!.toUtc().toIso8601String(),
            if (feature.seatsAvailable != null)
              'seatsAvailable': feature.seatsAvailable,
            'listingType': feature.listingType,
            if (feature.bedrooms != null) 'bedrooms': feature.bedrooms,
            'location': feature.location,
            'serviceArea': feature.serviceArea,
          },
        if (input.todayMenu == null && input.businessFeature == null)
          'businessFeature': null,
      },
    );
    final post = _postFromJson(_object(body, 'post'));
    unawaited(
      AnalyticsService.instance.log(
        'post_created',
        parameters: {
          'post_type': input.todayMenu != null
              ? 'today_menu'
              : input.businessFeature?.type.apiValue ?? 'standard',
          'has_media': input.media.isNotEmpty ? 1 : 0,
        },
      ),
    );
    return post;
  }

  Map<String, Object?> _postInputBody(CreatePostInput input) => {
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
    'mentionedUserIds': input.mentionedUserIds,
  };

  @override
  Future<CommunityPost> createPersonalPost(CreatePostInput input) async {
    final body = await _api.post(
      '/api/community/v1/me/posts',
      body: _postInputBody(input),
    );
    final post = _postFromJson(_object(body, 'post'));
    unawaited(
      AnalyticsService.instance.log(
        'post_created',
        parameters: {
          'post_type': 'personal',
          'has_media': input.media.isNotEmpty ? 1 : 0,
        },
      ),
    );
    return post;
  }

  @override
  Future<List<CommunityShareResult>> sharePersonalPostToCommunities(
    String postId, {
    required Map<String, String> categoryByCommunity,
    String caption = '',
  }) async {
    final body = await _api.post(
      '/api/community/v1/posts/$postId/community-shares',
      body: {
        'caption': caption,
        'destinations': categoryByCommunity.entries
            .map(
              (entry) => {'communityId': entry.key, 'categoryId': entry.value},
            )
            .toList(),
      },
    );
    return _list(body, 'results')
        .map(
          (json) => CommunityShareResult(
            communityId: json['communityId']?.toString() ?? '',
            status: json['status']?.toString() ?? 'failed',
            message: json['message']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
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
        'mentionedUserIds': input.mentionedUserIds,
        'anonymousAsAdmin': input.anonymousAsAdmin,
        'anonymousAsMember': input.anonymousAsMember,
        'importantAnnouncement': input.importantAnnouncement,
        if (input.todayMenu case final menu?)
          'businessFeature': {
            'type': 'today_menu',
            'dishes': menu.dishes
                .map(
                  (dish) => {
                    'name': dish.name,
                    'price': dish.price,
                    'available': dish.available,
                  },
                )
                .toList(),
            'fulfillmentOptions': menu.fulfillmentOptions
                .map((option) => option.apiValue)
                .toList(),
            'expiresAt': menu.expiresAt.toUtc().toIso8601String(),
          },
        if (input.businessFeature case final feature?)
          'businessFeature': {
            'type': feature.type.apiValue,
            'title': feature.title,
            'price': feature.price,
            'available': feature.available,
            'fulfillmentOptions': feature.fulfillmentOptions
                .map((option) => option.apiValue)
                .toList(),
            if (feature.expiresAt != null)
              'expiresAt': feature.expiresAt!.toUtc().toIso8601String(),
            'routeFrom': feature.routeFrom,
            'routeTo': feature.routeTo,
            if (feature.departureAt != null)
              'departureAt': feature.departureAt!.toUtc().toIso8601String(),
            if (feature.seatsAvailable != null)
              'seatsAvailable': feature.seatsAvailable,
            'listingType': feature.listingType,
            if (feature.bedrooms != null) 'bedrooms': feature.bedrooms,
            'location': feature.location,
            'serviceArea': feature.serviceArea,
          },
        if (input.todayMenu == null && input.businessFeature == null)
          'businessFeature': null,
      },
    );
    return _postFromJson(_object(body, 'post'));
  }

  @override
  Future<void> deletePost(String postId) async {
    await _api.delete('/api/community/v1/posts/$postId');
  }

  @override
  Future<void> setPostPinned(String postId, {required bool pinned}) async {
    if (pinned) {
      await _api.put('/api/community/v1/posts/$postId/pin');
    } else {
      await _api.delete('/api/community/v1/posts/$postId/pin');
    }
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
      // Newly uploaded assets are not attached yet, so the public media proxy
      // cannot serve them. The upload response contains a temporary read URL
      // specifically for the editor preview.
      url: media['url'] as String? ?? '',
      type: media['type'] as String? ?? 'image',
      blobName: media['blobName'] as String?,
      thumbnailUrl: media['thumbnailUrl'] as String?,
      thumbnailBlobName: media['thumbnailBlobName'] as String?,
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
    final comment = _commentFromJson(_object(body, 'comment'));
    unawaited(
      AnalyticsService.instance.log(
        'post_commented',
        parameters: {'is_reply': parentCommentId == null ? 0 : 1},
      ),
    );
    return comment;
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
  Future<void> setPostHidden(String postId, {required bool hidden}) async {
    final path = '/api/community/v1/me/hidden-posts/$postId';
    if (hidden) {
      await _api.put(path);
    } else {
      await _api.delete(path);
    }
  }

  @override
  Future<void> reportPost(
    String postId,
    String reason, {
    String category = 'other',
    bool hidePost = false,
    String? communityId,
  }) async {
    await _api.post(
      '/api/community/v1/posts/$postId/reports',
      body: {
        'reason': reason,
        'category': category,
        'hidePost': hidePost,
        if (communityId != null && communityId.isNotEmpty)
          'communityId': communityId,
      },
    );
  }

  @override
  Future<void> reportComment(
    String commentId,
    String reason, {
    String category = 'other',
  }) async {
    await _api.post(
      '/api/community/v1/comments/$commentId/reports',
      body: {'reason': reason, 'category': category},
    );
  }

  @override
  Future<void> reportMember(
    String userId,
    String reason, {
    String category = 'other',
  }) async {
    await _api.post(
      '/api/community/v1/users/$userId/reports',
      body: {'reason': reason, 'category': category},
    );
  }

  @override
  Future<void> reportCommunity(
    String communityId,
    String reason, {
    String category = 'other',
  }) async {
    await _api.post(
      '/api/community/v1/communities/$communityId/platform-reports',
      body: {'reason': reason, 'category': category},
    );
  }

  @override
  Future<void> appealCommunityBan(String communityId, String reason) async {
    await _api.post(
      '/api/community/v1/communities/$communityId/ban-appeals',
      body: {'reason': reason},
    );
  }

  @override
  Future<void> contactWicchuSafety(
    String communityId,
    String reason, {
    required String issue,
  }) async {
    await _api.post(
      '/api/community/v1/communities/$communityId/safety-requests',
      body: {'reason': reason, 'issue': issue},
    );
  }

  @override
  Future<List<PlatformReport>> listPlatformReports({
    bool resolved = false,
  }) async {
    final body = await _api.get(
      '/api/community/v1/platform/reports?status=${resolved ? 'resolved' : 'pending'}',
    );
    return _list(body, 'reports')
        .map((json) {
          final community = json['community'] is Map<String, dynamic>
              ? json['community'] as Map<String, dynamic>
              : const <String, dynamic>{};
          final reporter = json['reporter'] is Map<String, dynamic>
              ? json['reporter'] as Map<String, dynamic>
              : const <String, dynamic>{};
          final target = json['targetUser'] is Map<String, dynamic>
              ? json['targetUser'] as Map<String, dynamic>
              : const <String, dynamic>{};
          final resolver = json['resolvedByUser'] is Map<String, dynamic>
              ? json['resolvedByUser'] as Map<String, dynamic>
              : const <String, dynamic>{};
          return PlatformReport(
            id: _id(json),
            targetType: switch (json['targetType']) {
              'community_admin' => PlatformReportTargetType.communityAdmin,
              'message' => PlatformReportTargetType.message,
              'post' => PlatformReportTargetType.post,
              'comment' => PlatformReportTargetType.comment,
              'user' => PlatformReportTargetType.user,
              _ => PlatformReportTargetType.community,
            },
            targetId: json['targetId']?.toString() ?? '',
            communityId: json['communityId']?.toString() ?? '',
            communityName:
                community['name']?.toString() ??
                (json['targetType'] == 'message'
                    ? 'Direct messages'
                    : json['targetType'] == 'post' ||
                          json['targetType'] == 'comment'
                    ? 'Wicchu Safety'
                    : 'Community'),
            reporterName:
                reporter['displayName']?.toString() ??
                reporter['name']?.toString() ??
                'Wicchu member',
            targetName:
                target['displayName']?.toString() ??
                target['name']?.toString() ??
                community['name']?.toString() ??
                (json['targetType'] == 'post'
                    ? 'Personal publication'
                    : json['targetType'] == 'comment'
                    ? 'Comment'
                    : 'Community'),
            category: json['category']?.toString() ?? 'other',
            reason: json['reason']?.toString() ?? '',
            status: json['status']?.toString() ?? 'pending',
            createdAt:
                DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            evidence: json['evidence'] is Map<String, dynamic>
                ? json['evidence'] as Map<String, dynamic>
                : const {},
            actions: (json['actions'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map((action) {
                  final moderator = action['moderator'] is Map<String, dynamic>
                      ? action['moderator'] as Map<String, dynamic>
                      : const <String, dynamic>{};
                  return PlatformModerationAction(
                    action: action['action']?.toString() ?? '',
                    moderatorName:
                        moderator['displayName']?.toString() ??
                        moderator['name']?.toString() ??
                        'Wicchu moderator',
                    note: action['note']?.toString() ?? '',
                    createdAt:
                        DateTime.tryParse(
                          action['createdAt']?.toString() ?? '',
                        ) ??
                        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                  );
                })
                .toList(growable: false),
            resolvedAt: DateTime.tryParse(json['resolvedAt']?.toString() ?? ''),
            resolvedByName:
                resolver['displayName']?.toString() ??
                resolver['name']?.toString(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> decidePlatformReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    await _api.patch(
      '/api/community/v1/platform/reports/$reportId',
      body: {
        'action': action,
        if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
      },
    );
  }

  @override
  Future<List<CommunityRewardRequest>> listCommunityRewardRequests() async {
    final body = await _api.get('/api/community/v1/platform/reward-requests');
    return _list(body, 'requests')
        .map(
          (item) => CommunityRewardRequest(
            id: item['_id']?.toString() ?? '',
            communityId: item['communityId']?.toString() ?? '',
            countryCode: item['countryCode']?.toString() ?? '',
            countryName: item['countryName']?.toString(),
            contactEmail: item['contactEmail']?.toString() ?? '',
            note: item['note']?.toString(),
            requestedAt:
                DateTime.tryParse(item['requestedAt']?.toString() ?? '') ??
                DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> reviewCommunityRewardRequest(
    String requestId, {
    required bool approve,
    String currency = 'USD',
    String? note,
  }) async {
    await _api.patch(
      '/api/community/v1/platform/reward-requests/$requestId',
      body: {
        'status': approve ? 'approved' : 'rejected',
        if (approve) 'currency': currency,
        if (note?.trim().isNotEmpty ?? false) 'reviewNote': note!.trim(),
      },
    );
  }

  @override
  Future<List<PlatformRewardPayout>> listPlatformRewardPayouts({
    bool completed = false,
  }) async {
    final body = await _api.get(
      '/api/community/v1/platform/reward-payouts?status=${completed ? 'completed' : 'open'}',
    );
    return _list(body, 'payouts')
        .map((item) {
          final attribution = item['attribution'] is Map<String, dynamic>
              ? item['attribution'] as Map<String, dynamic>
              : const <String, dynamic>{};
          return PlatformRewardPayout(
            id: item['_id']?.toString() ?? '',
            communityName: item['communityName']?.toString() ?? 'Community',
            contactEmail: item['contactEmail']?.toString() ?? '',
            periodStart:
                DateTime.tryParse(item['periodStart']?.toString() ?? '') ??
                DateTime.now(),
            rewardCents: (item['rewardCents'] as num?)?.toInt() ?? 0,
            currency: item['currency']?.toString() ?? 'EUR',
            status: item['status']?.toString() ?? 'pending_review',
            reviewNote: item['reviewNote']?.toString(),
            availableBalanceCents:
                (item['availableBalanceCents'] as num?)?.toInt() ?? 0,
            minimumPayoutCents:
                (item['minimumPayoutCents'] as num?)?.toInt() ?? 2500,
            attributedJoins: (attribution['joined'] as num?)?.toInt() ?? 0,
            attributedNewUsers: (attribution['newUsers'] as num?)?.toInt() ?? 0,
            attributedActive7d:
                (attribution['activeAfter7Days'] as num?)?.toInt() ?? 0,
            attributedActive30d:
                (attribution['activeAfter30Days'] as num?)?.toInt() ?? 0,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> reviewPlatformRewardPayout(
    String payoutId, {
    required String action,
    String? note,
  }) async {
    await _api.patch(
      '/api/community/v1/platform/reward-payouts/$payoutId',
      body: {
        'action': action,
        if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
      },
    );
  }

  @override
  Future<PlatformAnalytics> getPlatformAnalytics() async {
    final responses = await Future.wait([
      _api.get('/api/community/v1/platform/analytics'),
      _api.get('/api/community/v1/platform/translation-analytics'),
    ]);
    final body = responses[0];
    final analytics = _object(body, 'analytics');
    final translation = _object(responses[1], 'analytics');
    final translationTotals = translation['totals'] is Map<String, dynamic>
        ? translation['totals'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final translationLimits = translation['limits'] is Map<String, dynamic>
        ? translation['limits'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final budget = translationLimits['monthlyBudgetUsd'] is Map<String, dynamic>
        ? translationLimits['monthlyBudgetUsd'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return PlatformAnalytics(
      translationRequests:
          (translationTotals['requests'] as num?)?.toInt() ?? 0,
      translationErrors: (translationTotals['errors'] as num?)?.toInt() ?? 0,
      translationAverageLatencyMs:
          (translationTotals['averageLatencyMs'] as num?)?.toDouble() ?? 0,
      translationEstimatedCostUsd:
          (translationTotals['estimatedCostUsd'] as num?)?.toDouble() ?? 0,
      translationMonthlyBudgetUsedUsd:
          (budget['used'] as num?)?.toDouble() ?? 0,
      translationMonthlyBudgetLimitUsd:
          (budget['limit'] as num?)?.toDouble() ?? 20,
      registeredUsers: (analytics['registeredUsers'] as num?)?.toInt() ?? 0,
      newRegistrations: (analytics['newRegistrations'] as num?)?.toInt() ?? 0,
      dailyActiveUsers: (analytics['dailyActiveUsers'] as num?)?.toInt() ?? 0,
      weeklyActiveUsers: (analytics['weeklyActiveUsers'] as num?)?.toInt() ?? 0,
      monthlyActiveUsers:
          (analytics['monthlyActiveUsers'] as num?)?.toInt() ?? 0,
      monthlyRetentionPercent: (analytics['monthlyRetentionPercent'] as num?)
          ?.toDouble(),
      activeCommunities: (analytics['activeCommunities'] as num?)?.toInt() ?? 0,
      participatingCommunities:
          (analytics['participatingCommunities'] as num?)?.toInt() ?? 0,
      pendingReviews: (analytics['pendingReviews'] as num?)?.toInt() ?? 0,
      registrationsByLocation:
          (analytics['registrationsByLocation'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => PlatformLocationRegistration(
                  location: item['location']?.toString() ?? '',
                  users: (item['users'] as num?)?.toInt() ?? 0,
                ),
              )
              .where((item) => item.location.isNotEmpty)
              .toList(growable: false),
      currencySummary: (analytics['currencySummary'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => PlatformCurrencySummary(
              currency: item['currency']?.toString() ?? 'EUR',
              pendingCents: (item['pendingCents'] as num?)?.toInt() ?? 0,
              approvedCents: (item['approvedCents'] as num?)?.toInt() ?? 0,
              paidCents: (item['paidCents'] as num?)?.toInt() ?? 0,
              remainingBudgetCents:
                  (item['remainingBudgetCents'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false),
      communityPerformance:
          (analytics['communityPerformance'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map((item) {
                final attribution = item['attribution'] is Map<String, dynamic>
                    ? item['attribution'] as Map<String, dynamic>
                    : const <String, dynamic>{};
                return PlatformCommunityPerformance(
                  name: item['name']?.toString() ?? 'Community',
                  currency: item['currency']?.toString() ?? 'EUR',
                  members: (item['members'] as num?)?.toInt() ?? 0,
                  monthlyActive: (item['monthlyActive'] as num?)?.toInt() ?? 0,
                  posts: (item['posts'] as num?)?.toInt() ?? 0,
                  interactions: (item['interactions'] as num?)?.toInt() ?? 0,
                  contributors: (item['contributors'] as num?)?.toInt() ?? 0,
                  newUsers: (attribution['newUsers'] as num?)?.toInt() ?? 0,
                  activeAfter7Days:
                      (attribution['activeAfter7Days'] as num?)?.toInt() ?? 0,
                  activeAfter30Days:
                      (attribution['activeAfter30Days'] as num?)?.toInt() ?? 0,
                );
              })
              .toList(growable: false),
    );
  }

  FinancialSupportApplication _financialSupportApplication(
    Map<String, dynamic> item,
  ) => FinancialSupportApplication(
    id: item['id']?.toString() ?? '',
    pageId: item['pageId']?.toString() ?? '',
    pageName: item['pageName']?.toString(),
    countryCode: item['countryCode']?.toString() ?? '',
    countryName: item['countryName']?.toString() ?? '',
    recipientType: item['recipientType']?.toString() ?? 'individual',
    purpose: item['purpose']?.toString() ?? '',
    contactEmail: item['contactEmail']?.toString() ?? '',
    status: item['status']?.toString() ?? 'pending',
    requestedAt:
        DateTime.tryParse(item['requestedAt']?.toString() ?? '') ??
        DateTime.now(),
    reviewedAt: DateTime.tryParse(item['reviewedAt']?.toString() ?? ''),
    reviewNote: item['reviewNote']?.toString() ?? '',
    providerStatus: item['providerStatus']?.toString() ?? 'not_configured',
    paymentsEnabled: item['paymentsEnabled'] == true,
  );

  @override
  Future<FinancialSupportApplication?> getFinancialSupportApplication(
    String pageId,
  ) async {
    final body = await _api.get(
      '/api/community/v1/pages/$pageId/support-application',
    );
    final item = body['application'];
    return item is Map<String, dynamic>
        ? _financialSupportApplication(item)
        : null;
  }

  @override
  Future<FinancialSupportApplication> submitFinancialSupportApplication(
    String pageId, {
    required String countryCode,
    String? countryName,
    required String recipientType,
    required String purpose,
    required String contactEmail,
  }) async {
    final body = await _api.post(
      '/api/community/v1/pages/$pageId/support-application',
      body: {
        'countryCode': countryCode,
        if (countryName?.trim().isNotEmpty ?? false)
          'countryName': countryName!.trim(),
        'recipientType': recipientType,
        'purpose': purpose.trim(),
        'contactEmail': contactEmail.trim(),
      },
    );
    return _financialSupportApplication(_object(body, 'application'));
  }

  @override
  Future<List<FinancialSupportApplication>>
  listFinancialSupportApplications() async {
    final body = await _api.get(
      '/api/community/v1/platform/support-applications',
    );
    return (body['applications'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_financialSupportApplication)
        .toList(growable: false);
  }

  @override
  Future<void> reviewFinancialSupportApplication(
    String applicationId, {
    required bool approve,
    String? note,
  }) async {
    await _api.patch(
      '/api/community/v1/platform/support-applications/$applicationId',
      body: {
        'status': approve ? 'approved' : 'rejected',
        if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
      },
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
  Future<CommunityInsights> getCommunityInsights(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/insights',
    );
    final insights = _object(body, 'insights');
    final growth = insights['memberGrowth'];
    final monetization = insights['monetization'] is Map<String, dynamic>
        ? insights['monetization'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final enrollment = monetization['enrollment'] is Map<String, dynamic>
        ? monetization['enrollment'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return CommunityInsights(
      totalMembers: (insights['totalMembers'] as num?)?.toInt() ?? 0,
      newMembers30d: (insights['newMembers30d'] as num?)?.toInt() ?? 0,
      newMembersChangePercent: (insights['newMembersChangePercent'] as num?)
          ?.toDouble(),
      monthlyActiveUsers:
          (insights['monthlyActiveUsers'] as num?)?.toInt() ?? 0,
      weeklyActiveUsers: (insights['weeklyActiveUsers'] as num?)?.toInt() ?? 0,
      monthlyActivityRate:
          (insights['monthlyActivityRate'] as num?)?.toDouble() ?? 0,
      posts30d: (insights['posts30d'] as num?)?.toInt() ?? 0,
      comments30d: (insights['comments30d'] as num?)?.toInt() ?? 0,
      reactions30d: (insights['reactions30d'] as num?)?.toInt() ?? 0,
      interactions30d: (insights['interactions30d'] as num?)?.toInt() ?? 0,
      uniqueContributors30d:
          (insights['uniqueContributors30d'] as num?)?.toInt() ?? 0,
      monthlyRetentionRate:
          (insights['monthlyRetentionRate'] as num?)?.toDouble() ?? 0,
      retentionDataAvailable:
          insights['retentionDataAvailable'] as bool? ?? false,
      memberGrowth: growth is List
          ? growth
                .whereType<Map<String, dynamic>>()
                .map((point) {
                  return MemberGrowthPoint(
                    date: DateTime.parse(point['date'] as String),
                    members: (point['members'] as num?)?.toInt() ?? 0,
                  );
                })
                .toList(growable: false)
          : const [],
      monetization: CommunityMonetizationEligibility(
        eligible: monetization['eligible'] as bool? ?? false,
        currency: monetization['currency']?.toString() ?? 'EUR',
        reviewRequired: monetization['reviewRequired'] as bool? ?? true,
        evaluationPeriodStart: DateTime.tryParse(
          monetization['evaluationPeriodStart']?.toString() ?? '',
        ),
        evaluationPeriodEnd: DateTime.tryParse(
          monetization['evaluationPeriodEnd']?.toString() ?? '',
        ),
        daysRemaining: (monetization['daysRemaining'] as num?)?.toInt() ?? 0,
        payoutSetupComplete:
            monetization['payoutSetupComplete'] as bool? ?? false,
        availableBalanceCents:
            (monetization['availableBalanceCents'] as num?)?.toInt() ?? 0,
        minimumPayoutCents:
            (monetization['minimumPayoutCents'] as num?)?.toInt() ?? 2500,
        enrollment: CommunityRewardEnrollment(
          requested: enrollment['requested'] as bool? ?? false,
          status: enrollment['status']?.toString() ?? 'not_requested',
          accepted: enrollment['accepted'] as bool? ?? false,
          countryCode: enrollment['countryCode']?.toString(),
          countryName: enrollment['countryName']?.toString(),
          contactEmail: enrollment['contactEmail']?.toString(),
          currency: enrollment['currency']?.toString(),
          termsVersion: enrollment['termsVersion']?.toString(),
          requestedAt: DateTime.tryParse(
            enrollment['requestedAt']?.toString() ?? '',
          ),
          acceptedAt: DateTime.tryParse(
            enrollment['acceptedAt']?.toString() ?? '',
          ),
          reviewNote: enrollment['reviewNote']?.toString(),
        ),
        currentTier: _rewardTier(monetization['currentTier']),
        nextTier: _rewardTier(monetization['nextTier']),
        tiers: monetization['tiers'] is List
            ? (monetization['tiers'] as List)
                  .map(_rewardTier)
                  .whereType<CommunityRewardTier>()
                  .toList(growable: false)
            : const [],
        history: monetization['history'] is List
            ? (monetization['history'] as List)
                  .map(_rewardEvaluation)
                  .whereType<CommunityRewardEvaluation>()
                  .toList(growable: false)
            : const [],
        goodStanding: monetization['goodStanding'] as bool? ?? true,
        restrictionReason: monetization['restrictionReason']?.toString(),
      ),
    );
  }

  @override
  Future<CommunityRewardEnrollment> acceptCommunityRewardTerms(
    String communityId, {
    required String countryCode,
  }) async {
    final body = await _api.put(
      '/api/community/v1/communities/$communityId/admin/rewards/enrollment',
      body: {'accepted': true},
    );
    final enrollment = _object(body, 'enrollment');
    return CommunityRewardEnrollment(
      accepted: enrollment['accepted'] as bool? ?? false,
      countryCode: enrollment['countryCode']?.toString(),
      currency: enrollment['currency']?.toString(),
      termsVersion: enrollment['termsVersion']?.toString(),
      acceptedAt: DateTime.tryParse(enrollment['acceptedAt']?.toString() ?? ''),
    );
  }

  @override
  Future<CommunityRewardEnrollment> requestCommunityRewards(
    String communityId, {
    required String countryCode,
    String? countryName,
    required String contactEmail,
    String? note,
  }) async {
    final body = await _api.post(
      '/api/community/v1/communities/$communityId/admin/rewards/request',
      body: {
        'countryCode': countryCode,
        if (countryName?.trim().isNotEmpty ?? false)
          'countryName': countryName!.trim(),
        'contactEmail': contactEmail.trim(),
        if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
      },
    );
    final enrollment = _object(body, 'enrollment');
    return CommunityRewardEnrollment(
      requested: true,
      status: enrollment['status']?.toString() ?? 'pending',
      countryCode: enrollment['countryCode']?.toString(),
      countryName: enrollment['countryName']?.toString(),
      contactEmail: enrollment['contactEmail']?.toString(),
      requestedAt: DateTime.tryParse(
        enrollment['requestedAt']?.toString() ?? '',
      ),
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
  Future<List<CommunityPost>> listRemovedPosts(String communityId) async {
    final body = await _api.get(
      '/api/community/v1/communities/$communityId/admin/removed-posts',
    );
    return _list(body, 'posts').map(_postFromJson).toList(growable: false);
  }

  @override
  Future<void> removePost(
    String communityId,
    String postId, {
    required String reason,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/admin/posts/$postId/remove',
      body: {'reason': reason},
    );
  }

  @override
  Future<void> restorePost(
    String communityId,
    String postId, {
    required String reason,
  }) async {
    await _api.patch(
      '/api/community/v1/communities/$communityId/admin/posts/$postId/restore',
      body: {'reason': reason},
    );
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
        .map((json) {
          final reporter = json['reporter'] is Map<String, dynamic>
              ? json['reporter'] as Map<String, dynamic>
              : const <String, dynamic>{};
          final target = json['targetPreview'] is Map<String, dynamic>
              ? json['targetPreview'] as Map<String, dynamic>
              : const <String, dynamic>{};
          final targetAuthor = target['author'] is Map<String, dynamic>
              ? target['author'] as Map<String, dynamic>
              : const <String, dynamic>{};
          return CommunityReport(
            id: _id(json),
            reporterId: json['reporterId']?.toString() ?? '',
            communityId: json['communityId']?.toString() ?? '',
            targetType: switch (json['targetType']) {
              'comment' => ModerationTargetType.comment,
              'member' => ModerationTargetType.member,
              _ => ModerationTargetType.post,
            },
            targetId: json['targetId']?.toString() ?? '',
            category: json['category'] as String? ?? 'other',
            reason: json['reason'] as String? ?? '',
            status: ReportStatus.open,
            createdAt:
                DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            reporterName: reporter['name']?.toString(),
            reporterAvatarUrl: reporter['avatarUrl']?.toString(),
            targetAuthorName: targetAuthor['name']?.toString(),
            targetAuthorAvatarUrl: targetAuthor['avatarUrl']?.toString(),
            targetText: target['text']?.toString(),
            targetStatus: target['status']?.toString(),
            targetPostId: target['postId']?.toString(),
            targetMediaCount: (target['mediaCount'] as num?)?.toInt() ?? 0,
          );
        })
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

  static BusinessCatalogCategory _businessCatalogCategoryFromJson(
    Map<String, dynamic> json,
  ) => BusinessCatalogCategory(
    id: _id(json),
    name: json['name']?.toString() ?? '',
    position: (json['position'] as num?)?.toInt() ?? 0,
    active: json['active'] != false,
  );

  static BusinessProduct _businessProductFromJson(Map<String, dynamic> json) =>
      BusinessProduct(
        id: _id(json),
        categoryId: json['categoryId']?.toString() ?? '',
        kind: json['kind'] == 'daily_menu'
            ? BusinessProductKind.dailyMenu
            : BusinessProductKind.product,
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'USD',
        imageUrl: json['imageUrl']?.toString(),
        available: json['available'] != false,
        quantityAvailable: (json['quantityAvailable'] as num?)?.toInt(),
        variants: (json['variants'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (variant) => BusinessProductVariant(
                id: _id(variant),
                name: variant['name']?.toString() ?? '',
                sku: variant['sku']?.toString() ?? '',
                priceCents: (variant['priceCents'] as num?)?.toInt(),
                available: variant['available'] != false,
                quantityAvailable: (variant['quantityAvailable'] as num?)
                    ?.toInt(),
                attributes: {
                  for (final attribute
                      in (variant['attributes'] as List? ?? const [])
                          .whereType<Map<String, dynamic>>())
                    if ((attribute['name']?.toString() ?? '').isNotEmpty)
                      attribute['name'].toString():
                          attribute['value']?.toString() ?? '',
                },
              ),
            )
            .toList(growable: false),
        expiresAt: _optionalDate(json['expiresAt']),
        position: (json['position'] as num?)?.toInt() ?? 0,
      );

  static BusinessCatalog _businessCatalogFromJson(Map<String, dynamic> json) =>
      BusinessCatalog(
        businessId: json['businessId']?.toString() ?? '',
        businessName: json['businessName']?.toString() ?? '',
        acceptingOrders: json['acceptingOrders'] == true,
        fulfillmentOptions: (json['fulfillmentOptions'] as List? ?? const [])
            .map(BusinessFulfillmentOption.fromApi)
            .whereType<BusinessFulfillmentOption>()
            .toList(growable: false),
        whatsapp: json['whatsapp']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'USD',
        categories: (json['categories'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_businessCatalogCategoryFromJson)
            .toList(growable: false),
        products: (json['products'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(_businessProductFromJson)
            .toList(growable: false),
      );

  static BusinessOrder _businessOrderFromJson(Map<String, dynamic> json) {
    final fulfillment =
        BusinessFulfillmentOption.fromApi(json['fulfillmentMethod']) ??
        BusinessFulfillmentOption.pickup;
    final business = json['business'] is Map<String, dynamic>
        ? json['business'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final customer = json['customer'] is Map<String, dynamic>
        ? json['customer'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return BusinessOrder(
      id: _id(json),
      businessId: json['businessId']?.toString() ?? '',
      businessName: business['name']?.toString() ?? '',
      orderNumber: (json['orderNumber'] as num?)?.toInt() ?? 0,
      status: BusinessOrderStatus.fromApi(json['status']),
      fulfillmentMethod: fulfillment,
      customerName: customer['name']?.toString() ?? '',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'USD',
      subtotalCents: (json['subtotalCents'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => BusinessOrderItem(
              productId: item['productId']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              quantity: (item['quantity'] as num?)?.toInt() ?? 0,
              unitPriceCents: (item['unitPriceCents'] as num?)?.toInt() ?? 0,
              totalCents: (item['totalCents'] as num?)?.toInt() ?? 0,
              imageUrl: item['imageUrl']?.toString(),
              variantId: item['variantId']?.toString(),
              variantName: item['variantName']?.toString() ?? '',
              sku: item['sku']?.toString() ?? '',
            ),
          )
          .toList(growable: false),
      createdAt:
          _optionalDate(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static BusinessRequestSettings _businessRequestSettingsFromJson(
    Map<String, dynamic> json,
  ) => BusinessRequestSettings(
    businessId: json['businessId']?.toString() ?? '',
    businessName: json['businessName']?.toString() ?? '',
    acceptingRequests: json['acceptingRequests'] == true,
    capabilities: (json['capabilities'] as List? ?? const [])
        .map(BusinessRequestType.fromApi)
        .whereType<BusinessRequestType>()
        .toList(growable: false),
  );

  static BusinessRequest _businessRequestFromJson(Map<String, dynamic> json) {
    final customer = json['customer'] is Map<String, dynamic>
        ? json['customer'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return BusinessRequest(
      id: _id(json),
      businessId: json['businessId']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      requestNumber: (json['requestNumber'] as num?)?.toInt() ?? 0,
      type:
          BusinessRequestType.fromApi(json['type']) ??
          BusinessRequestType.service,
      status: BusinessRequestStatus.fromApi(json['status']),
      serviceName: json['serviceName']?.toString() ?? '',
      customerName: customer['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      preferredAt: _optionalDate(json['preferredAt']),
      scheduledAt: _optionalDate(json['scheduledAt']),
      quotedPriceCents: (json['quotedPriceCents'] as num?)?.toInt(),
      currency: json['currency']?.toString() ?? 'USD',
      businessMessage: json['businessMessage']?.toString() ?? '',
      attachments: (json['attachments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => item['url']?.toString() ?? '')
          .where((url) => url.isNotEmpty)
          .map((url) => BusinessRequestAttachment(url: url))
          .toList(growable: false),
      createdAt:
          _optionalDate(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

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
    final scope = json['scope'] == 'global'
        ? CommunityScope.global
        : CommunityScope.local;
    final townJson = json['town'] is Map<String, dynamic>
        ? json['town'] as Map<String, dynamic>
        : scope == CommunityScope.global
        ? <String, dynamic>{'_id': '', 'name': 'Everywhere', 'countryCode': ''}
        : null;
    if (townJson == null) {
      throw const ApiException('Community town data is missing.');
    }
    return Community(
      id: _id(json),
      name: json['name'] as String? ?? '',
      profileCategory: ProfileCategory.fromApi(json['profileCategory']),
      businessServices: (json['businessServices'] as List? ?? const [])
          .map(BusinessService.fromApi)
          .whereType<BusinessService>()
          .take(maxBusinessServices)
          .toList(growable: false),
      businessAcceptingRequests: json['businessAcceptingRequests'] == true,
      businessAcceptingOrders: json['businessAcceptingOrders'] == true,
      businessRequestCapabilities:
          (json['businessRequestCapabilities'] as List? ?? const [])
              .map(BusinessRequestType.fromApi)
              .whereType<BusinessRequestType>()
              .toList(growable: false),
      slug: json['slug'] as String? ?? '',
      type: json['type'] == 'public_profile'
          ? CommunityType.publicProfile
          : CommunityType.community,
      scope: scope,
      shortDescription: json['shortDescription'] as String? ?? '',
      description: json['description'] as String? ?? '',
      town: _townFromJson(townJson),
      imageUrl: _mediaUrl(json['imageUrl'] as String?, json['imageBlobName']),
      coverImageUrl: _mediaUrl(
        json['coverImageUrl'] as String?,
        json['coverImageBlobName'],
      ),
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
      membershipStatus: switch (json['membershipStatus']) {
        'active' => MembershipStatus.active,
        'pending' => MembershipStatus.pending,
        'banned' => MembershipStatus.banned,
        _ => null,
      },
      banPublicReason: json['banPublicReason']?.toString(),
      banExpiresAt: _optionalDate(json['banExpiresAt']),
      canManagePageInbox: json['canManagePageInbox'] == true,
      canManagePageOrders: json['canManagePageOrders'] == true,
      canManagePageServices: json['canManagePageServices'] == true,
      canViewPageAnalytics: json['canViewPageAnalytics'] == true,
      canManageLocalNews: json['canManageLocalNews'] == true,
      published: json['published'] != false,
      accentColor: json['accentColor']?.toString() ?? 'teal',
      neonBordersEnabled: json['neonBordersEnabled'] == true,
      neonBorderAnimation: neonBorderAnimationFromApi(
        json['neonBorderAnimation'],
      ),
      neonAnimationDurationSeconds:
          (json['neonAnimationDurationSeconds'] as num?)?.toDouble() ?? 5,
      headerBorderEnabled: json['headerBorderEnabled'] == true,
      approvalRequired: json['approvalRequired'] as bool? ?? false,
      membersListVisible: json['membersListVisible'] as bool? ?? true,
      showWeather: json['showWeather'] as bool? ?? false,
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
      links: (json['links'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (link) => CommunityLink(
              label: link['label']?.toString() ?? '',
              url: link['url']?.toString() ?? '',
            ),
          )
          .where((link) => link.label.isNotEmpty && link.url.isNotEmpty)
          .toList(growable: false),
      businessLocation: json['businessLocation'] is Map<String, dynamic>
          ? BusinessLocation(
              address:
                  (json['businessLocation'] as Map<String, dynamic>)['address']
                      ?.toString() ??
                  '',
              latitude:
                  ((json['businessLocation']
                              as Map<String, dynamic>)['latitude']
                          as num?)
                      ?.toDouble(),
              longitude:
                  ((json['businessLocation']
                              as Map<String, dynamic>)['longitude']
                          as num?)
                      ?.toDouble(),
              showExactAddress:
                  (json['businessLocation']
                      as Map<String, dynamic>)['showExactAddress'] ==
                  true,
            )
          : null,
      businessHours: (json['businessHours'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (hours) => BusinessHour(
              day: hours['day']?.toString() ?? '',
              open: hours['open']?.toString() ?? '',
              close: hours['close']?.toString() ?? '',
              closed: hours['closed'] == true,
            ),
          )
          .where((hours) => hours.day.isNotEmpty)
          .toList(growable: false),
      businessFulfillmentOptions:
          (json['businessFulfillmentOptions'] as List? ?? const [])
              .map(BusinessFulfillmentOption.fromApi)
              .whereType<BusinessFulfillmentOption>()
              .toList(growable: false),
      businessContact: json['businessContact'] is Map<String, dynamic>
          ? BusinessContact(
              phone:
                  (json['businessContact'] as Map<String, dynamic>)['phone']
                      ?.toString() ??
                  '',
              whatsapp:
                  (json['businessContact'] as Map<String, dynamic>)['whatsapp']
                      ?.toString() ??
                  '',
            )
          : const BusinessContact(),
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
              url: _mediaUrl(item['url'] as String?, item['blobName']) ?? '',
              type: item['type'] as String? ?? 'image',
              blobName: item['blobName'] as String?,
              thumbnailUrl: _mediaUrl(
                item['thumbnailUrl'] as String?,
                item['thumbnailBlobName'],
              ),
              thumbnailBlobName: item['thumbnailBlobName'] as String?,
            ),
          )
          .toList(growable: false),
      status: switch (json['status']) {
        'pending_approval' || 'pendingApproval' => PostStatus.pendingApproval,
        'removed' || 'rejected' => PostStatus.removed,
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
      canInteract: json['canInteract'] as bool? ?? true,
      canShareToCommunities: json['canShareToCommunities'] as bool? ?? false,
      businessViewCount: (json['businessViewCount'] as num?)?.toInt() ?? 0,
      businessContactCount:
          (json['businessContactCount'] as num?)?.toInt() ?? 0,
      editedAt: _optionalDate(json['editedAt']),
      promotion: json['promotion'] is Map<String, dynamic>
          ? _postPromotionFromJson(json['promotion'] as Map<String, dynamic>)
          : null,
      poll: json['poll'] is Map<String, dynamic>
          ? _pollFromJson(json['poll'] as Map<String, dynamic>)
          : null,
      todayMenu:
          json['businessFeature'] is Map<String, dynamic> &&
              (json['businessFeature'] as Map<String, dynamic>)['type'] ==
                  'today_menu'
          ? _todayMenuFromJson(json['businessFeature'] as Map<String, dynamic>)
          : null,
      businessFeature:
          json['businessFeature'] is Map<String, dynamic> &&
              (json['businessFeature'] as Map<String, dynamic>)['type'] !=
                  'today_menu'
          ? _businessFeatureFromJson(
              json['businessFeature'] as Map<String, dynamic>,
            )
          : null,
      mentionedUserIds: (json['mentionedUserIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      isAnonymous: authorJson['isAnonymous'] as bool? ?? false,
      moderationReason:
          (json['moderation'] as Map<String, dynamic>?)?['reason']
              ?.toString() ??
          '',
      reviewedAt: _optionalDate(
        (json['moderation'] as Map<String, dynamic>?)?['reviewedAt'],
      ),
      destinationType: json['destinationType']?.toString() ?? 'community',
      sourceCommunityId: json['sourceCommunityId']?.toString(),
      shareCaption:
          (json['communityShare'] as Map<String, dynamic>?)?['caption']
              ?.toString() ??
          json['shareCaption']?.toString() ??
          '',
      isCommunityShare:
          json['isCommunityShare'] == true ||
          json['communityShare'] is Map<String, dynamic>,
      importantAnnouncement: json['importantAnnouncement'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      canPin: json['canPin'] as bool? ?? false,
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

  static TodayMenu _todayMenuFromJson(Map<String, dynamic> json) => TodayMenu(
    dishes: (json['dishes'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (dish) => TodayMenuDish(
            name: dish['name']?.toString() ?? '',
            price: dish['price']?.toString() ?? '',
            available: dish['available'] != false,
          ),
        )
        .toList(growable: false),
    fulfillmentOptions: (json['fulfillmentOptions'] as List? ?? const [])
        .map(BusinessFulfillmentOption.fromApi)
        .whereType<BusinessFulfillmentOption>()
        .toList(growable: false),
    expiresAt:
        DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  static BusinessPostFeature? _businessFeatureFromJson(
    Map<String, dynamic> json,
  ) {
    final type = BusinessPostFeatureType.fromApi(json['type']);
    if (type == null) return null;
    return BusinessPostFeature(
      type: type,
      title: json['title']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      available: json['available'] != false,
      fulfillmentOptions: (json['fulfillmentOptions'] as List? ?? const [])
          .map(BusinessFulfillmentOption.fromApi)
          .whereType<BusinessFulfillmentOption>()
          .toList(growable: false),
      expiresAt: _optionalDate(json['expiresAt']),
      routeFrom: json['routeFrom']?.toString() ?? '',
      routeTo: json['routeTo']?.toString() ?? '',
      departureAt: _optionalDate(json['departureAt']),
      seatsAvailable: (json['seatsAvailable'] as num?)?.toInt(),
      listingType: json['listingType']?.toString() ?? '',
      bedrooms: (json['bedrooms'] as num?)?.toInt(),
      location: json['location']?.toString() ?? '',
      serviceArea: json['serviceArea']?.toString() ?? '',
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
      authorAvatarUrl: authorJson['avatarUrl'] as String?,
      text: json['text'] as String? ?? '',
      parentCommentId: json['parentCommentId']?.toString(),
      replyToCommentId: json['replyToCommentId']?.toString(),
      replyToUserId: json['replyToUserId']?.toString(),
      replyToName: json['replyToUser'] is Map<String, dynamic>
          ? (json['replyToUser'] as Map<String, dynamic>)['name'] as String?
          : null,
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
      orderId: json['orderId']?.toString() ?? '',
      requestId: json['requestId']?.toString() ?? '',
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

  static ScopedNotificationPreferences _scopedPreferencesFromJson(
    Map<String, dynamic> body, {
    ScopedNotificationPreferences defaults =
        const ScopedNotificationPreferences(),
  }) {
    final value = body['preferences'];
    final json = value is Map<String, dynamic> ? value : body;
    return ScopedNotificationPreferences(
      mode: ContentNotificationMode.values.firstWhere(
        (mode) => mode.name == json['mode'],
        orElse: () => defaults.mode,
      ),
      selectedCategoryIds: (json['selectedCategoryIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      contentTypes: (json['contentTypes'] as List? ?? const ['posts'])
          .map((value) => value.toString())
          .toList(growable: false),
      pushEnabled: json['pushEnabled'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> _scopedPreferencesToJson(
    ScopedNotificationPreferences preferences,
  ) => {
    'mode': preferences.mode.name,
    'selectedCategoryIds': preferences.selectedCategoryIds,
    'contentTypes': preferences.contentTypes,
    'pushEnabled': preferences.pushEnabled,
  };

  static CommunityNotificationType _notificationType(
    String? value,
  ) => switch (value) {
    'user_follow' => CommunityNotificationType.userFollow,
    'post_comment' || 'postComment' => CommunityNotificationType.postComment,
    'comment_reaction' => CommunityNotificationType.commentReaction,
    'comment_reply' => CommunityNotificationType.commentReply,
    'post_mention' => CommunityNotificationType.postMention,
    'new_post' => CommunityNotificationType.newPost,
    'new_personal_post' => CommunityNotificationType.newPersonalPost,
    'today_menu' => CommunityNotificationType.todayMenu,
    'business_order' => CommunityNotificationType.businessOrder,
    'business_request' => CommunityNotificationType.businessRequest,
    'post_approved' => CommunityNotificationType.postApproved,
    'post_rejected' => CommunityNotificationType.postRejected,
    'post_removed' => CommunityNotificationType.postRemoved,
    'post_restored' => CommunityNotificationType.postRestored,
    'comment_approved' => CommunityNotificationType.commentApproved,
    'comment_rejected' => CommunityNotificationType.commentRejected,
    'comment_removed' => CommunityNotificationType.commentRemoved,
    'member_removed' => CommunityNotificationType.memberRemoved,
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
    'reward_request' => CommunityNotificationType.rewardRequest,
    'reward_request_approved' =>
      CommunityNotificationType.rewardRequestApproved,
    'reward_request_rejected' =>
      CommunityNotificationType.rewardRequestRejected,
    'reward_payout_approved' => CommunityNotificationType.rewardPayoutApproved,
    'reward_payout_rejected' => CommunityNotificationType.rewardPayoutRejected,
    'reward_payout_paid' => CommunityNotificationType.rewardPayoutPaid,
    _ => CommunityNotificationType.postReaction,
  };

  static String _id(Map<String, dynamic> json) =>
      (json['_id'] ?? json['id'])?.toString() ?? '';

  static List<Map<String, dynamic>> _array(
    Map<String, dynamic> body,
    String key,
  ) => (body[key] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();

  static CommunityInvitation _invitationFromJson(
    Map<String, dynamic> json, {
    String? invitationUrl,
  }) {
    final community = json['community'];
    final communityJson = community is Map<String, dynamic>
        ? community
        : const <String, dynamic>{};
    final invitedUser = json['invitedUser'] is Map<String, dynamic>
        ? json['invitedUser'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return CommunityInvitation(
      id: _id(json),
      communityId:
          json['communityId']?.toString() ??
          communityJson['id']?.toString() ??
          '',
      type: json['type']?.toString() ?? 'email',
      email: json['email']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      communityName: communityJson['name']?.toString(),
      communityImageUrl: communityJson['imageUrl']?.toString(),
      communityType: communityJson['type'] == 'public_profile'
          ? CommunityType.publicProfile
          : CommunityType.community,
      invitationUrl: invitationUrl,
      invitedUserName: invitedUser['name']?.toString(),
      invitedUserAvatarUrl: invitedUser['avatarUrl']?.toString(),
    );
  }

  static CommunityHelpfulness _helpfulnessFromJson(Map<String, dynamic> json) =>
      CommunityHelpfulness(
        responseCount: (json['responseCount'] as num?)?.toInt() ?? 0,
        minimumResponses: (json['minimumResponses'] as num?)?.toInt() ?? 10,
        helpfulPercentage: (json['helpfulPercentage'] as num?)?.toInt(),
        isPublic: json['isPublic'] == true,
        eligible: json['eligible'] == true,
        myVote: _surveyResponseFromJson(json['myVote']),
        insights: _feedbackInsightsFromJson(json['insights']),
      );

  static CommunitySurveyResponse? _surveyResponseFromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['helpful'] is! bool) {
      return null;
    }
    return CommunitySurveyResponse(
      helpful: value['helpful'] as bool,
      locallyRelevant: value['locallyRelevant']?.toString(),
      safeParticipation: value['safeParticipation']?.toString(),
      wellOrganized: value['wellOrganized']?.toString(),
      recommend: value['recommend'] as bool?,
    );
  }

  static Map<String, CommunityFeedbackInsight> _feedbackInsightsFromJson(
    Object? value,
  ) {
    if (value is! Map<String, dynamic>) return const {};
    return value.map((key, item) {
      final json = item is Map<String, dynamic>
          ? item
          : const <String, dynamic>{};
      return MapEntry(
        key,
        CommunityFeedbackInsight(
          total: (json['total'] as num?)?.toInt() ?? 0,
          yesPercentage: (json['yesPercentage'] as num?)?.toInt(),
        ),
      );
    });
  }

  static CommunityRole? _roleFromJson(Object? value) => switch (value) {
    'owner' => CommunityRole.owner,
    'admin' => CommunityRole.admin,
    'moderator' => CommunityRole.moderator,
    'member' => CommunityRole.member,
    _ => null,
  };
}
