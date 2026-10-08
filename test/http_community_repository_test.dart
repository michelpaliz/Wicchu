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
    if (path == '/api/community/v1/me/profile') {
      return {
        'profile': {
          'name': 'Ana Rivera',
          'userName': 'ana',
          'bio': 'Community volunteer',
          'location': 'Dénia',
          'socialLinks': {
            'whatsapp': '+34600123456',
            'facebook': 'ana',
            'instagram': 'ana',
          },
        },
      };
    }
    if (path.startsWith(
      '/api/community/v1/me/profile/username-availability?',
    )) {
      return {'available': !path.contains('userName=taken')};
    }
    if (path ==
        '/api/community/v1/communities/community-1/admin/removed-posts') {
      return {
        'posts': [
          {
            'id': 'post-removed',
            'communityId': 'community-1',
            'categoryId': 'category-1',
            'authorId': 'user-2',
            'author': {'id': 'user-2', 'name': 'Ana'},
            'text': 'Removed update',
            'status': 'removed',
            'createdAt': '2026-10-01T10:00:00.000Z',
            'moderation': {
              'reason': 'Rules violation',
              'reviewedAt': '2026-10-02T10:00:00.000Z',
            },
          },
        ],
      };
    }
    if (path.contains('/api/community/v1/messages/conversations') &&
        path.contains('pageId=page-1')) {
      return {
        'conversations': [
          {
            'id': 'page-conversation-1',
            'otherUser': {'id': 'user-3', 'name': 'Customer'},
            'pageId': 'page-1',
            'pageName': 'Como en Casa',
            'viewingAsPage': true,
            'otherIsPage': false,
            'label': 'order',
            'lastMessagePreview': 'Is delivery available?',
            'unreadCount': 1,
            'requestStatus': path.contains('requests=true')
                ? 'pending'
                : 'accepted',
            'requestedByMe': false,
            'canSendMessage': !path.contains('requests=true'),
          },
        ],
      };
    }
    if (path == '/api/community/v1/messages/conversations' ||
        path == '/api/community/v1/messages/conversations?requests=true') {
      return {
        'conversations': [
          {
            'id': 'conversation-1',
            'otherUser': {'id': 'user-2', 'name': 'Ana', 'avatarUrl': null},
            'lastMessagePreview': 'Hello',
            'lastMessageAt': '2026-10-05T10:00:00.000Z',
            'unreadCount': 2,
            if (path.contains('requests=true')) ...{
              'requestStatus': 'pending',
              'requestedByMe': false,
              'canSendMessage': false,
            },
          },
        ],
      };
    }
    if (path == '/api/community/v1/messages/privacy') {
      return {'messagingPrivacy': 'shared_communities'};
    }
    if (path.startsWith('/api/community/v1/users?')) {
      return {
        'people': [
          {
            'id': 'user-2',
            'name': 'Ana Rivera',
            'userName': 'ana',
            'avatarUrl': null,
            'sharedCommunityCount': 2,
          },
        ],
        'nextCursor': 'MjU',
      };
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
    if (path.startsWith('/api/community/v1/businesses/nearby?')) {
      return {'communities': <Map<String, dynamic>>[]};
    }
    if (path.startsWith('/api/community/v1/businesses/posts?')) {
      return {'posts': <Map<String, dynamic>>[]};
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
    if (path.endsWith('/admin/reports')) {
      return {
        'reports': [
          {
            'id': 'report-1',
            'reporterId': 'reporter-1',
            'communityId': 'community-1',
            'targetType': 'comment',
            'targetId': 'comment-1',
            'category': 'harassment',
            'reason': 'Personal attack',
            'status': 'open',
            'createdAt': '2026-10-05T10:00:00.000Z',
            'reporter': {'name': 'Ana Rivera', 'avatarUrl': null},
            'targetPreview': {
              'author': {'name': 'Reported Member', 'avatarUrl': null},
              'text': 'An insulting comment',
              'status': 'published',
              'postId': 'post-1',
              'mediaCount': 0,
            },
          },
        ],
      };
    }
    if (path == '/api/community/v1/posts/post-1/share-kit') {
      return {
        'shareKit': {
          'canonicalUrl': 'https://wicchu.com/posts/post-1',
          'message': 'Community meeting\n\nhttps://wicchu.com/posts/post-1',
          'targets': {
            'whatsapp': 'https://wa.me/?text=Community%20meeting',
            'facebook': 'https://facebook.com/share/post-1',
            'copyLink': 'https://wicchu.com/posts/post-1',
          },
          'images': {
            'instagramFeed': 'https://wicchu.com/posts/post-1/card/feed.png',
            'instagramStory': 'https://wicchu.com/posts/post-1/card/story.png',
          },
        },
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
      if (body?['pageId'] != null) {
        return {
          'conversation': {
            'id': 'page-conversation-1',
            'otherUser': {'id': body?['pageId'], 'name': 'Como en Casa'},
            'pageId': body?['pageId'],
            'pageName': 'Como en Casa',
            'viewingAsPage': false,
            'otherIsPage': true,
            'communityInbox': body?['pageId'] == 'community-1',
            'unreadCount': 0,
            'requestStatus': 'pending',
            'requestedByMe': true,
            'canSendMessage': true,
          },
        };
      }
      return {
        'conversation': {
          'id': 'conversation-1',
          'otherUser': {'id': body?['userId'], 'name': 'Ana'},
          'unreadCount': 0,
          'requestStatus': 'pending',
          'requestedByMe': true,
          'canSendMessage': true,
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
    if (path == '/api/community/v1/communities/business-1/posts') {
      return {
        'post': {
          'id': 'menu-post-1',
          'communityId': 'business-1',
          'categoryId': body?['categoryId'],
          'author': {'id': 'current-user', 'name': 'Restaurant owner'},
          'text': body?['text'],
          'status': 'published',
          'createdAt': '2026-10-07T10:00:00.000Z',
          'businessFeature': body?['businessFeature'],
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
    if (path == '/api/community/v1/me/profile') {
      return {
        'profile': {...?body},
      };
    }
    if (path.startsWith('/api/community/v1/posts/')) {
      return {
        'post': {
          'id': path.split('/').last,
          'communityId': 'business-1',
          'categoryId': body?['categoryId'],
          'author': {'id': 'current-user', 'name': 'Business owner'},
          'text': body?['text'],
          'status': 'published',
          'createdAt': '2026-10-07T10:00:00.000Z',
          'businessFeature': body?['businessFeature'],
        },
      };
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
  test('removed posts can be listed and restored with a reason', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final posts = await repository.listRemovedPosts('community-1');
    expect(posts.single.status, PostStatus.removed);
    expect(posts.single.moderationReason, 'Rules violation');
    expect(posts.single.reviewedAt, DateTime.utc(2026, 10, 2, 10));

    await repository.restorePost(
      'community-1',
      'post-removed',
      reason: 'Decision reviewed',
    );
    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/admin/posts/post-removed/restore',
    );
    expect(api.lastBody, {'reason': 'Decision reviewed'});
  });

  test(
    'editable profile loads, validates username and saves all fields',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final profile = await repository.getEditableProfile();
      expect(profile.name, 'Ana Rivera');
      expect(profile.bio, 'Community volunteer');
      expect(await repository.isUsernameAvailable('available'), isTrue);
      expect(await repository.isUsernameAvailable('taken'), isFalse);

      await repository.updateEditableProfile(profile);
      expect(api.lastPath, '/api/community/v1/me/profile');
      expect(api.lastBody?['name'], 'Ana Rivera');
      expect(api.lastBody?['socialLinks'], {
        'whatsapp': '+34600123456',
        'facebook': 'ana',
        'instagram': 'ana',
      });
    },
  );

  test('people search is paginated and never expects an email', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final page = await repository.searchPeople(
      query: 'Ana Rivera',
      cursor: 'previous',
      limit: 25,
    );

    final uri = Uri.parse(api.lastPath!);
    expect(uri.path, '/api/community/v1/users');
    expect(uri.queryParameters, {
      'query': 'Ana Rivera',
      'limit': '25',
      'cursor': 'previous',
    });
    expect(page.people.single.name, 'Ana Rivera');
    expect(page.people.single.userName, 'ana');
    expect(page.people.single.sharedCommunityCount, 2);
    expect(page.nextCursor, 'MjU');
  });

  test('direct messaging uses private conversation endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final conversations = await repository.listDirectConversations();
    expect(conversations.single.otherUser.name, 'Ana');
    expect(conversations.single.unreadCount, 2);

    final started = await repository.startDirectConversation('user-2');
    expect(started.id, 'conversation-1');
    expect(started.requestStatus, MessageRequestStatus.pending);
    expect(started.requestedByMe, isTrue);
    expect(started.canSendMessage, isTrue);
    expect(api.lastBody, {'userId': 'user-2'});

    final requests = await repository.listMessageRequests();
    expect(requests.single.requestStatus, MessageRequestStatus.pending);
    expect(requests.single.requestedByMe, isFalse);
    expect(requests.single.canSendMessage, isFalse);
    expect(
      api.lastPath,
      '/api/community/v1/messages/conversations?requests=true',
    );

    await repository.respondToMessageRequest('conversation-1', accept: true);
    expect(
      api.lastPath,
      '/api/community/v1/messages/conversations/conversation-1/request',
    );
    expect(api.lastBody, {'action': 'accept'});

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

  test(
    'page messaging addresses and filters the selected page inbox',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final started = await repository.startPageConversation('page-1');
      expect(api.lastBody, {'pageId': 'page-1'});
      expect(started.otherIsPage, isTrue);
      expect(started.pageName, 'Como en Casa');

      final communityChat = await repository.startPageConversation(
        'community-1',
      );
      expect(communityChat.communityInbox, isTrue);

      final conversations = await repository.listDirectConversations(
        pageId: 'page-1',
      );
      expect(
        api.lastPath,
        '/api/community/v1/messages/conversations?pageId=page-1',
      );
      expect(conversations.single.viewingAsPage, isTrue);
      expect(conversations.single.otherUser.name, 'Customer');
      expect(conversations.single.label, ConversationLabel.order);

      await repository.updateDirectConversationLabel(
        'page-conversation-1',
        ConversationLabel.completed,
      );
      expect(
        api.lastPath,
        '/api/community/v1/messages/conversations/page-conversation-1/label',
      );
      expect(api.lastBody, {'label': 'completed'});

      final requests = await repository.listMessageRequests(pageId: 'page-1');
      expect(
        api.lastPath,
        '/api/community/v1/messages/conversations?requests=true&pageId=page-1',
      );
      expect(requests.single.requestStatus, MessageRequestStatus.pending);
    },
  );

  test('page owner can grant an administrator shared inbox access', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.setPageInboxAccess('page-1', 'admin-1', enabled: true);

    expect(
      api.lastPath,
      '/api/community/v1/communities/page-1/members/admin-1/page-inbox',
    );
    expect(api.lastBody, {'pageInboxAccess': true});
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

  test('community report queue maps reporter and content previews', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final report = (await repository.listReports('community-1')).single;

    expect(report.targetType, ModerationTargetType.comment);
    expect(report.reporterName, 'Ana Rivera');
    expect(report.targetAuthorName, 'Reported Member');
    expect(report.targetText, 'An insulting comment');
    expect(report.targetPostId, 'post-1');
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
      shortDescription: 'A short profile summary',
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
    expect(api.lastBody?['shortDescription'], 'A short profile summary');

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

    await repository.updateCommunity(
      Community(
        id: 'business-1',
        name: 'Restaurant',
        description: '',
        town: town,
        visibility: CommunityVisibility.public,
        createdBy: 'user-1',
        createdAt: createdAt,
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.localBusiness,
        businessServices: const [BusinessService.food],
      ),
      town: town,
      name: 'Restaurant',
      description: '',
      visibility: CommunityVisibility.public,
      approvalRequired: false,
      showWeather: false,
      links: const [],
      profileCategory: ProfileCategory.localBusiness,
      businessServices: const [BusinessService.food],
      businessLocation: null,
      businessHours: const [
        BusinessHour(day: 'monday', open: '09:00', close: '18:00'),
      ],
      businessFulfillmentOptions: const [
        BusinessFulfillmentOption.delivery,
        BusinessFulfillmentOption.eatIn,
      ],
      businessContact: const BusinessContact(
        phone: '+593123456789',
        whatsapp: '+593987654321',
      ),
    );
    expect(api.lastBody?['businessHours'], [
      {'day': 'monday', 'open': '09:00', 'close': '18:00', 'closed': false},
    ]);
    expect(api.lastBody?['businessFulfillmentOptions'], ['delivery', 'eat_in']);
    expect(api.lastBody?['businessContact'], {
      'phone': '+593123456789',
      'whatsapp': '+593987654321',
    });
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

  test('business discovery sends location mode parameters', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.listLocalBusinesses(townId: 'town-1');
    var uri = Uri.parse(api.lastPath!);
    expect(uri.path, '/api/community/v1/communities');
    expect(uri.queryParameters['profileCategory'], 'local_business');
    expect(uri.queryParameters['townId'], 'town-1');

    await repository.listNearbyBusinesses(
      latitude: -1.43,
      longitude: -79.28,
      radiusKm: 10,
    );
    uri = Uri.parse(api.lastPath!);
    expect(uri.path, '/api/community/v1/businesses/nearby');
    expect(uri.queryParameters['radiusKm'], '10.0');

    await repository.listBusinessPosts(['business-1', 'business-2']);
    uri = Uri.parse(api.lastPath!);
    expect(uri.path, '/api/community/v1/businesses/posts');
    expect(uri.queryParameters['businessIds'], 'business-1,business-2');
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
        shortDescription: 'Neighbors connected',
        description: 'Local updates',
        town: town,
        visibility: CommunityVisibility.public,
        categoryNames: ['News', 'Events'],
        approvalRequired: true,
      ),
    );

    expect(api.lastPath, '/api/community/v1/communities');
    expect(api.lastBody?['townId'], 'town-1');
    expect(api.lastBody?['shortDescription'], 'Neighbors connected');
    expect(api.lastBody?['categoryNames'], ['News', 'Events']);
    expect(api.lastBody?['approvalRequired'], isTrue);
    expect(community.shortDescription, 'Neighbors connected');
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

  test('today menu posts send structured restaurant details', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    final expiresAt = DateTime.utc(2026, 10, 8);

    final post = await repository.createPost(
      'business-1',
      CreatePostInput(
        categoryId: 'posts',
        text: "🍴 Today's menu",
        todayMenu: TodayMenu(
          expiresAt: expiresAt,
          dishes: const [
            TodayMenuDish(name: 'Sancocho', price: r'$5', available: true),
          ],
          fulfillmentOptions: const [BusinessFulfillmentOption.delivery],
        ),
      ),
    );

    expect(api.lastPath, '/api/community/v1/communities/business-1/posts');
    expect(api.lastBody?['businessFeature'], {
      'type': 'today_menu',
      'dishes': [
        {'name': 'Sancocho', 'price': r'$5', 'available': true},
      ],
      'fulfillmentOptions': ['delivery'],
      'expiresAt': expiresAt.toIso8601String(),
    });
    expect(post.todayMenu?.dishes.single.name, 'Sancocho');
    expect(post.todayMenu?.fulfillmentOptions, [
      BusinessFulfillmentOption.delivery,
    ]);
  });

  test('specialized business posts preserve their structured type', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    final features = [
      const BusinessPostFeature(
        type: BusinessPostFeatureType.retailOffer,
        title: 'Weekend offer',
        price: r'$10',
        fulfillmentOptions: [BusinessFulfillmentOption.pickup],
      ),
      BusinessPostFeature(
        type: BusinessPostFeatureType.transportTrip,
        routeFrom: 'Echeandía',
        routeTo: 'Guaranda',
        departureAt: DateTime.utc(2026, 10, 9, 14),
        seatsAvailable: 4,
      ),
      const BusinessPostFeature(
        type: BusinessPostFeatureType.realEstateListing,
        title: 'Family home',
        price: r'$400',
        listingType: 'rent',
        bedrooms: 3,
        location: 'Central Echeandía',
      ),
      const BusinessPostFeature(
        type: BusinessPostFeatureType.professionalService,
        title: 'Accounting support',
        serviceArea: 'Bolívar',
      ),
    ];

    for (final feature in features) {
      final post = await repository.createPost(
        'business-1',
        CreatePostInput(
          categoryId: 'posts',
          text: feature.title.isEmpty ? feature.routeFrom : feature.title,
          businessFeature: feature,
        ),
      );
      expect(
        (api.lastBody?['businessFeature'] as Map<String, dynamic>)['type'],
        feature.type.apiValue,
      );
      expect(post.businessFeature?.type, feature.type);
    }
  });

  test('business posts can be updated and engagement is recorded', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    const feature = BusinessPostFeature(
      type: BusinessPostFeatureType.retailOffer,
      title: 'Weekend offer',
      price: r'$10',
      available: false,
    );

    final post = await repository.updatePost(
      'offer-1',
      const CreatePostInput(
        categoryId: 'posts',
        text: 'Weekend offer',
        businessFeature: feature,
      ),
    );
    expect(api.lastPath, '/api/community/v1/posts/offer-1');
    expect(
      (api.lastBody?['businessFeature'] as Map<String, dynamic>)['available'],
      isFalse,
    );
    expect(post.businessFeature?.available, isFalse);

    await repository.recordBusinessPostEngagement('offer-1', action: 'contact');
    expect(api.lastPath, '/api/community/v1/posts/offer-1/business-engagement');
    expect(api.lastBody, {'action': 'contact'});
  });

  test('post detail accepts the pending approval status', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final post = await repository.getPost('post-1');

    expect(api.lastPath, '/api/community/v1/posts/post-1');
    expect(post.status, PostStatus.pendingApproval);
    expect(post.authorAvatarUrl, 'https://example.com/michael.jpg');
  });

  test(
    'post share kit preserves social targets and generated images',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final kit = await repository.getPostShareKit('post-1');

      expect(api.lastPath, '/api/community/v1/posts/post-1/share-kit');
      expect(kit.canonicalUrl, 'https://wicchu.com/posts/post-1');
      expect(kit.whatsappUrl, startsWith('https://wa.me/'));
      expect(kit.instagramFeedImageUrl, endsWith('/card/feed.png'));
      expect(kit.instagramStoryImageUrl, endsWith('/card/story.png'));
    },
  );

  test('comments preserve the author profile image', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final comments = await repository.listComments('post-1');

    expect(api.lastPath, '/api/community/v1/posts/post-1/comments');
    expect(comments.single.authorName, 'Michael Paliz');
    expect(comments.single.authorAvatarUrl, 'https://example.com/michael.jpg');
  });
}
