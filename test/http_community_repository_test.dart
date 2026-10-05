import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/http_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';

class _RecordingApiClient extends AuthenticatedApiClient {
  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    lastPath = path;
    if (path == '/api/community/v1/messages/conversations') {
      return {
        'conversations': [
          {
            'id': 'conversation-1',
            'otherUser': {'id': 'user-2', 'name': 'Ana', 'avatarUrl': null},
            'lastMessagePreview': 'Hello',
            'lastMessageAt': '2026-10-05T10:00:00.000Z',
            'unreadCount': 2,
          },
        ],
      };
    }
    if (path == '/api/community/v1/messages/privacy') {
      return {'messagingPrivacy': 'shared_communities'};
    }
    if (path.startsWith(
      '/api/community/v1/messages/conversations/conversation-1?',
    )) {
      return {
        'messages': [
          {
            'id': 'message-1',
            'conversationId': 'conversation-1',
            'senderId': 'user-2',
            'recipientId': 'current-user',
            'body': 'Hello',
            'createdAt': '2026-10-05T10:00:00.000Z',
          },
        ],
        'nextCursor': path.contains('before=') ? null : 'older-message-id',
      };
    }
    if (path == '/api/community/v1/me/invitations') {
      return {
        'invitations': [
          {
            'id': 'transfer-1',
            'communityId': 'community-1',
            'type': 'ownership_transfer',
            'status': 'pending',
            'createdAt': '2026-10-01T12:00:00.000Z',
            'expiresAt': '2026-10-08T12:00:00.000Z',
            'community': {'id': 'community-1', 'name': 'Riverside'},
          },
        ],
      };
    }
    if (path.endsWith('/admin/insights')) {
      return {
        'insights': {
          'totalMembers': 2043,
          'newMembers30d': 143,
          'newMembersChangePercent': 12.4,
          'monthlyActiveUsers': 527,
          'weeklyActiveUsers': 248,
          'monthlyActivityRate': 25.8,
          'posts30d': 84,
          'comments30d': 326,
          'reactions30d': 1204,
          'memberGrowth': [
            {'date': '2026-09-01', 'members': 1900},
            {'date': '2026-09-30', 'members': 2043},
          ],
        },
      };
    }
    if (path == '/api/community/v1/promotions/eligibility') {
      return {
        'eligibility': {
          'eligible': true,
          'trialStarted': false,
          'trialDays': 30,
          'maxCampaignDays': 7,
        },
      };
    }
    if (path.startsWith('/api/community/v1/communities/nearby?')) {
      return {'communities': <Map<String, dynamic>>[]};
    }
    if (path.startsWith('/api/community/v1/communities?')) {
      return {
        'communities': [
          {
            'id': 'community-1',
            'name': 'Riverside',
            'description': 'Local updates',
            'town': {'id': 'town-1', 'name': 'Town X', 'countryCode': 'EC'},
          },
        ],
      };
    }
    if (path.endsWith('/posts/post-1/comments')) {
      return {
        'comments': [
          {
            'id': 'comment-1',
            'postId': 'post-1',
            'text': 'Count me in',
            'createdAt': '2026-09-22T12:00:00.000Z',
            'author': {
              'id': 'user-1',
              'name': 'Michael Paliz',
              'avatarUrl': 'https://example.com/michael.jpg',
            },
          },
        ],
      };
    }
    if (path.contains('/posts/')) {
      return {
        'post': {
          'id': 'post-1',
          'communityId': 'community-1',
          'categoryId': 'category-1',
          'text': 'Community meeting',
          'status': 'pendingApproval',
          'author': {
            'id': 'user-1',
            'name': 'Michael Paliz',
            'avatarUrl': 'https://example.com/michael.jpg',
          },
        },
      };
    }
    return {'posts': <Map<String, dynamic>>[]};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    lastPath = path;
    lastBody = body;
    if (path == '/api/community/v1/messages/conversations') {
      return {
        'conversation': {
          'id': 'conversation-1',
          'otherUser': {'id': body?['userId'], 'name': 'Ana'},
          'unreadCount': 0,
        },
      };
    }
    if (path == '/api/community/v1/messages/conversations/conversation-1') {
      return {
        'message': {
          'id': 'message-2',
          'conversationId': 'conversation-1',
          'senderId': 'current-user',
          'recipientId': 'user-2',
          'body': body?['body'],
          'createdAt': '2026-10-05T10:01:00.000Z',
        },
      };
    }
    if (path == '/api/community/v1/towns/resolve') {
      return {
        'town': {
          'id': 'town-echeandia',
          'name': 'Echeandía',
          'countryCode': 'EC',
        },
      };
    }
    if (path == '/api/community/v1/promotions') {
      return {
        'campaign': {
          'id': 'promotion-1',
          'postId': body?['postId'],
          'communityId': 'community-1',
          'status': 'pending',
          'durationDays': body?['durationDays'],
          'impressionCount': 0,
          'clickCount': 0,
          'createdAt': '2026-09-22T12:00:00.000Z',
        },
      };
    }
    return {
      'community': {'id': 'community-1', ...?body},
    };
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    lastPath = path;
    lastBody = body;
    if (path == '/api/community/v1/messages/privacy') {
      return {'messagingPrivacy': body?['messagingPrivacy']};
    }
    return {
      'community': {
        'id': 'community-1',
        'name': body?['name'] ?? 'A page',
        'description': body?['description'] ?? '',
        'visibility': body?['visibility'] ?? 'public',
        'type': path.contains('community-1') ? 'community' : 'public_profile',
        ...?body,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    lastPath = path;
    return {'deleted': true};
  }
}

void main() {
  test('direct messaging uses private conversation endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final conversations = await repository.listDirectConversations();
    expect(conversations.single.otherUser.name, 'Ana');
    expect(conversations.single.unreadCount, 2);

    final started = await repository.startDirectConversation('user-2');
    expect(started.id, 'conversation-1');
    expect(api.lastBody, {'userId': 'user-2'});

    final messages = await repository.listDirectMessages('conversation-1');
    expect(messages.messages.single.body, 'Hello');
    expect(messages.nextCursor, 'older-message-id');
    final older = await repository.listDirectMessages(
      'conversation-1',
      before: messages.nextCursor,
    );
    expect(older.nextCursor, isNull);
    expect(api.lastPath, contains('before=older-message-id'));

    await repository.markDirectConversationRead('conversation-1');
    expect(
      api.lastPath,
      '/api/community/v1/messages/conversations/conversation-1/read',
    );

    final sent = await repository.sendDirectMessage(
      'conversation-1',
      'Private hello',
    );
    expect(sent.body, 'Private hello');
    expect(api.lastBody, {'body': 'Private hello'});

    await repository.reportDirectMessage(
      'message-1',
      'Harassment',
      category: 'harassment',
    );
    expect(api.lastPath, '/api/community/v1/messages/message-1/reports');
    expect(api.lastBody, {'reason': 'Harassment', 'category': 'harassment'});

    await repository.deleteDirectMessage('message-1', everyone: true);
    expect(api.lastPath, '/api/community/v1/messages/message-1?scope=everyone');
    await repository.deleteDirectConversation('conversation-1');
    expect(
      api.lastPath,
      '/api/community/v1/messages/conversations/conversation-1',
    );

    expect(
      await repository.getMessagingPrivacy(),
      MessagingPrivacy.sharedCommunities,
    );
    expect(
      await repository.updateMessagingPrivacy(MessagingPrivacy.nobody),
      MessagingPrivacy.nobody,
    );
    expect(api.lastBody, {'messagingPrivacy': 'nobody'});
  });

  test('comment and member reports use their moderation endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.reportComment(
      'comment-1',
      'Harassing reply',
      category: 'harassment',
    );
    expect(api.lastPath, '/api/community/v1/comments/comment-1/reports');
    expect(api.lastBody, {
      'reason': 'Harassing reply',
      'category': 'harassment',
    });

    await repository.reportMember('user-2', 'Impersonation', category: 'scam');
    expect(api.lastPath, '/api/community/v1/users/user-2/reports');
    expect(api.lastBody, {'reason': 'Impersonation', 'category': 'scam'});
  });

  test('community reports go to the platform moderation endpoint', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.reportCommunity(
      'community-1',
      'The administrators are abusing their role',
      category: 'harassment',
    );

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/platform-reports',
    );
    expect(api.lastBody, {
      'reason': 'The administrators are abusing their role',
      'category': 'harassment',
    });
  });

  test('reported posts can be hidden for the reporting user', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.reportPost(
      'post-1',
      'I do not want to see this again',
      category: 'harassment',
      hidePost: true,
    );

    expect(api.lastPath, '/api/community/v1/posts/post-1/reports');
    expect(api.lastBody, {
      'reason': 'I do not want to see this again',
      'category': 'harassment',
      'hidePost': true,
    });
  });

  test('member bans send public, private, and expiry details', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    final expiresAt = DateTime.utc(2026, 10, 9, 12);

    await repository.setMemberAccess(
      'community-1',
      'user-2',
      action: 'ban',
      reason: 'Repeated harassment',
      internalNote: 'Two moderator warnings were ignored',
      expiresAt: expiresAt,
    );

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/admin/members/user-2/access',
    );
    expect(api.lastBody, {
      'action': 'ban',
      'reason': 'Repeated harassment',
      'internalNote': 'Two moderator warnings were ignored',
      'expiresAt': '2026-10-09T12:00:00.000Z',
    });
  });

  test('ban appeals go directly to Wicchu Safety', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.appealCommunityBan(
      'community-1',
      'I believe this decision should be reviewed.',
    );

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/ban-appeals',
    );
    expect(api.lastBody, {
      'reason': 'I believe this decision should be reviewed.',
    });
  });

  test(
    'ownership transfers and administrator step-down use dedicated endpoints',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      await repository.createOwnershipTransfer('community-1', 'admin-2');
      expect(
        api.lastPath,
        '/api/community/v1/communities/community-1/ownership-transfers',
      );
      expect(api.lastBody, {'targetUserId': 'admin-2'});

      await repository.stepDownCommunityRole('community-1');
      expect(
        api.lastPath,
        '/api/community/v1/communities/community-1/membership/step-down',
      );

      final invitations = await repository.listMyCommunityInvitations();
      expect(invitations.single.isOwnershipTransfer, isTrue);
      expect(invitations.single.communityName, 'Riverside');
    },
  );

  test('community managers can contact Wicchu Safety', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.contactWicchuSafety(
      'community-1',
      'Another administrator changed our business information.',
      issue: 'admin_abuse',
    );

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/safety-requests',
    );
    expect(api.lastBody, {
      'reason': 'Another administrator changed our business information.',
      'issue': 'admin_abuse',
    });
  });

  test('community insights are decoded from the admin endpoint', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final insights = await repository.getCommunityInsights('community-1');

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/admin/insights',
    );
    expect(insights.totalMembers, 2043);
    expect(insights.monthlyActiveUsers, 527);
    expect(insights.monthlyActivityRate, 25.8);
    expect(insights.memberGrowth.last.members, 2043);
  });

  test(
    'public profile category is sent and decoded without relabeling legacy profiles',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);
      const town = Town(id: 'town-1', name: 'Town X', countryCode: 'EC');
      for (final category in [null, ...ProfileCategory.values]) {
        final profile = await repository.createCommunity(
          CreateCommunityInput(
            name: 'A profile',
            description: '',
            town: town,
            visibility: CommunityVisibility.public,
            categoryNames: ['Posts'],
            type: CommunityType.publicProfile,
            profileCategory: category,
          ),
        );
        expect(api.lastBody?['profileCategory'], category?.apiValue);
        expect(profile.profileCategory, category);
        expect(profile.spaceTypeLabel, category?.label ?? 'Public profile');
      }
      expect(ProfileCategory.fromApi('future_category'), isNull);
    },
  );

  test('page edits only send fields supported by the page type', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    const town = Town(id: 'town-1', name: 'Town X', countryCode: 'EC');
    final createdAt = DateTime.utc(2026, 1, 1);

    Future<void> update(
      Community community, {
      ProfileCategory? profileCategory,
      List<BusinessService> businessServices = const [],
    }) => repository.updateCommunity(
      community,
      town: town,
      name: 'Updated title',
      description: '',
      visibility: CommunityVisibility.public,
      approvalRequired: false,
      showWeather: false,
      links: const [],
      profileCategory: profileCategory,
      businessServices: businessServices,
      businessLocation: null,
    );

    await update(
      Community(
        id: 'community-1',
        name: 'Community',
        description: '',
        town: town,
        visibility: CommunityVisibility.public,
        createdBy: 'user-1',
        createdAt: createdAt,
      ),
    );
    expect(api.lastBody, isNot(contains('businessServices')));
    expect(api.lastBody, isNot(contains('businessLocation')));

    await update(
      Community(
        id: 'profile-1',
        name: 'Creator',
        description: '',
        town: town,
        visibility: CommunityVisibility.public,
        createdBy: 'user-1',
        createdAt: createdAt,
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.creator,
      ),
      profileCategory: ProfileCategory.creator,
    );
    expect(api.lastBody, isNot(contains('businessServices')));
    expect(api.lastBody?['businessLocation'], isNull);

    await update(
      Community(
        id: 'business-1',
        name: 'Business',
        description: '',
        town: town,
        visibility: CommunityVisibility.public,
        createdBy: 'user-1',
        createdAt: createdAt,
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.localBusiness,
      ),
      profileCategory: ProfileCategory.localBusiness,
      businessServices: const [BusinessService.gardening],
    );
    expect(api.lastBody?['businessServices'], ['gardening']);
    expect(api.lastBody?['businessLocation'], isNull);
  });

  test('nearby discovery sends coordinates to the API', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.listNearbyCommunities(latitude: 40.5, longitude: -3.7);

    final uri = Uri.parse(api.lastPath!);
    expect(uri.path, '/api/community/v1/communities/nearby');
    expect(uri.queryParameters['latitude'], '40.5');
    expect(uri.queryParameters['longitude'], '-3.7');
    expect(uri.queryParameters['radiusKm'], '25.0');
  });

  test(
    'community search and category sort use the API query parameters',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final communities = await repository.listCommunities(query: 'Town X');
      expect(api.lastPath, '/api/community/v1/communities?q=Town+X');
      expect(communities.single.name, 'Riverside');

      await repository.listPosts(
        'community-1',
        categoryId: 'category-1',
        sort: 'popular',
      );
      expect(
        api.lastPath,
        '/api/community/v1/communities/community-1/posts?categoryId=category-1&sort=popular',
      );
    },
  );

  test('location resolution registers and returns the detected town', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final town = await repository.locateTown(
      latitude: -1.4325,
      longitude: -79.2791,
    );

    expect(api.lastPath, '/api/community/v1/towns/resolve');
    expect(api.lastBody, {'latitude': -1.4325, 'longitude': -79.2791});
    expect(town.id, 'town-echeandia');
    expect(town.name, 'Echeandía');
  });

  test('community creation sends approval rules and category names', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    const town = Town(id: 'town-1', name: 'Town X', countryCode: 'EC');

    final community = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Riverside',
        description: 'Local updates',
        town: town,
        visibility: CommunityVisibility.public,
        categoryNames: ['News', 'Events'],
        approvalRequired: true,
      ),
    );

    expect(api.lastPath, '/api/community/v1/communities');
    expect(api.lastBody?['townId'], 'town-1');
    expect(api.lastBody?['categoryNames'], ['News', 'Events']);
    expect(api.lastBody?['approvalRequired'], isTrue);
    expect(community.myRole, CommunityRole.owner);
  });

  test('promotion eligibility and submission use the pilot API', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final eligibility = await repository.getPromotionEligibility();
    expect(eligibility.eligible, isTrue);
    expect(eligibility.trialDays, 30);

    final campaign = await repository.createPromotion(
      'post-1',
      durationDays: 7,
    );
    expect(api.lastPath, '/api/community/v1/promotions');
    expect(api.lastBody, {'postId': 'post-1', 'durationDays': 7});
    expect(campaign.status, PromotionStatus.pending);
    expect(campaign.durationDays, 7);
  });

  test('post detail accepts the pending approval status', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final post = await repository.getPost('post-1');

    expect(api.lastPath, '/api/community/v1/posts/post-1');
    expect(post.status, PostStatus.pendingApproval);
    expect(post.authorAvatarUrl, 'https://example.com/michael.jpg');
  });

  test('comments preserve the author profile image', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final comments = await repository.listComments('post-1');

    expect(api.lastPath, '/api/community/v1/posts/post-1/comments');
    expect(comments.single.authorName, 'Michael Paliz');
    expect(comments.single.authorAvatarUrl, 'https://example.com/michael.jpg');
  });
}
