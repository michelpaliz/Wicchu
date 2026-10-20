import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/http_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';

class _PreferenceDefaultsApiClient extends AuthenticatedApiClient {
  Map<String, dynamic> preferences = {};

  @override
  Future<Map<String, dynamic>> get(String path) async => {
    'preferences': preferences,
  };
}

class _NewsPostApiClient extends AuthenticatedApiClient {
  @override
  Future<Map<String, dynamic>> get(String path) async => {
    'posts': [
      {
        '_id': 'news-post-1',
        'communityId': 'pilot-community',
        'categoryId': 'category-1',
        'text': '## Council update\n\nA short factual summary.',
        'status': 'published',
        'createdAt': '2026-10-20T08:00:00.000Z',
        'newsSource': {
          'sourceName': 'Council',
          'articleUrl': 'https://publisher.example/article?ref=Original',
          'publishedAt': '2026-10-19T08:00:00.000Z',
        },
      },
    ],
  };
}

class _RecordingApiClient extends AuthenticatedApiClient {
  String? lastPath;
  String? lastMethod;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    lastPath = path;
    if (path == '/api/community/v1/news/sources') {
      return {
        'sources': [
          {
            '_id': 'source-1',
            'name': 'Local Gazette',
            'type': 'rss',
            'siteUrl': 'https://news.example',
            'trusted': true,
            'authorizedForAutoPublish': true,
          },
        ],
      };
    }
    if (path ==
        '/api/community/v1/communities/community-1/admin/news-settings') {
      return {
        'settings': {
          'enabled': true,
          'sourceIds': ['source-1'],
          'categoryIds': ['category-1'],
          'language': 'es',
          'approvalMode': 'manual',
          'subscriptionTier': 'pro',
        },
        'tierLimits': {'free': 0, 'pro': 60, 'business': 200},
        'plans': [
          {'tier': 'free', 'priceEur': 0, 'priceUsd': 0},
          {'tier': 'pro', 'priceEur': 4.99, 'priceUsd': 4.99},
          {'tier': 'business', 'priceEur': 9.99, 'priceUsd': 9.99},
        ],
      };
    }
    if (path ==
        '/api/community/v1/communities/community-2/admin/news-settings') {
      return {
        'settings': {
          'enabled': false,
          'sourceIds': <String>[],
          'categoryIds': <String>[],
          'language': 'es',
          'approvalMode': 'manual',
          'subscriptionTier': 'free',
        },
        'access': {
          'entitled': true,
          'source': 'pilot',
          'tier': 'pilot',
          'monthlyLimit': 60,
          'dailyLimit': 2,
        },
        'usage': {
          'month': '2026-10',
          'monthlyUsed': 5,
          'monthlyLimit': 60,
          'todayUsed': 1,
          'dailyLimit': 2,
        },
        'lastRun': {
          'trigger': 'scheduler',
          'status': 'partial',
          'errorReason': 'sources_unavailable',
          'finishedAt': '2026-10-19T08:00:00.000Z',
          'processed': 3,
          'pendingApproval': 1,
          'published': 0,
          'sourceErrors': 1,
        },
        'application': {
          'id': 'application-1',
          'communityId': 'community-2',
          'status': 'approved',
          'message': 'Please',
          'requestedAt': '2026-10-01T08:00:00.000Z',
          'reviewedAt': '2026-10-02T08:00:00.000Z',
          'reviewNote': 'Welcome',
        },
        'dashboard': {
          'status': 'awaiting_approval',
          'reason': null,
          'enabled': true,
          'collecting': false,
          'approvalMode': 'manual',
          'nextCollectionAt': '2026-10-19T21:16:31.000Z',
          'scheduleUnavailableReason': null,
          'schedulerIntervalMinutes': 60,
          'timezone': 'UTC',
          'quotaResetsAt': '2026-10-20T00:00:00.000Z',
          'pendingApproval': 2,
          'todayUsed': 1,
          'publishedToday': 0,
          'dailyLimit': 1,
          'monthlyUsed': 5,
          'monthlyLimit': 60,
          'lastRun': null,
        },
        'tierLimits': {'free': 0, 'pro': 60, 'business': 200},
        'plans': <Map<String, dynamic>>[],
      };
    }
    if (path == '/api/community/v1/communities/pilot-community') {
      return {
        'community': {
          '_id': 'pilot-community',
          'town': {'_id': 'town-1', 'name': 'Dénia', 'countryCode': 'ES'},
          'name': 'Denia',
          'description': '',
          'visibility': 'public',
          'createdBy': 'user-1',
          'myRole': 'admin',
          'canManageLocalNews': true,
        },
      };
    }
    if (path == '/api/community/v1/communities/other-community') {
      return {
        'community': {
          '_id': 'other-community',
          'town': {'_id': 'town-1', 'name': 'Dénia', 'countryCode': 'ES'},
          'name': 'Elsewhere',
          'description': '',
          'visibility': 'public',
          'createdBy': 'user-1',
          'myRole': 'admin',
        },
      };
    }
    if (path ==
        '/api/community/v1/communities/community-1/admin/news-articles') {
      return {
        'articles': [
          {
            '_id': 'article-1',
            'title': 'Community update',
            'status': 'pending_approval',
            'sourceUrl': 'https://news.example/article',
            'createdAt': '2026-10-19T08:00:00.000Z',
          },
        ],
      };
    }
    if (path == '/api/community/v1/platform/translation-analytics') {
      return {
        'analytics': {
          'totals': {
            'requests': 12,
            'errors': 1,
            'averageLatencyMs': 320,
            'estimatedCostUsd': 0.04,
          },
          'limits': {
            'monthlyBudgetUsd': {'used': 0.04, 'limit': 20},
          },
        },
      };
    }
    if (path == '/api/community/v1/pages/page-1/support-application') {
      return {'application': null};
    }
    if (path == '/api/community/v1/platform/support-applications') {
      return {
        'applications': [
          {
            'id': 'support-1',
            'pageId': 'page-1',
            'pageName': 'Local Project',
            'countryCode': 'EC',
            'recipientType': 'community_project',
            'purpose': 'Support community workshops and local activities.',
            'contactEmail': 'project@example.com',
            'status': 'pending',
            'requestedAt': '2026-10-16T10:00:00.000Z',
            'providerStatus': 'not_configured',
            'paymentsEnabled': false,
          },
        ],
      };
    }
    if (path == '/api/community/v1/businesses/business-1/catalog') {
      return {
        'catalog': {
          'businessId': 'business-1',
          'businessName': 'Burger House',
          'acceptingOrders': true,
          'fulfillmentOptions': ['delivery', 'pickup'],
          'whatsapp': '+593999999999',
          'categories': [
            {'id': 'burgers', 'name': 'Burgers', 'position': 0},
          ],
          'products': [
            {
              'id': 'classic',
              'categoryId': 'burgers',
              'kind': 'product',
              'name': 'Classic burger',
              'priceCents': 450,
              'available': true,
              'quantityAvailable': 8,
              'variants': [
                {
                  'id': 'variant-medium-blue',
                  'name': 'Medium · Blue',
                  'sku': 'TS-M-BLU',
                  'priceCents': 500,
                  'available': true,
                  'quantityAvailable': 3,
                  'attributes': [
                    {'name': 'Size', 'value': 'M'},
                    {'name': 'Color', 'value': 'Blue'},
                  ],
                },
              ],
            },
          ],
        },
      };
    }
    if (path == '/api/community/v1/businesses/business-1/request-settings') {
      return {
        'settings': {
          'businessId': 'business-1',
          'businessName': 'Jardines Michel',
          'acceptingRequests': true,
          'capabilities': ['quote', 'service'],
        },
      };
    }
    if (path == '/api/community/v1/me/notifications') {
      return {
        'notifications': [
          {
            'id': 'notification-1',
            'actor': {'name': 'Ana'},
            'type': 'new_post',
            'postId': 'post-1',
            'communityId': 'community-1',
            'message': 'published a new post',
            'createdAt': '2026-10-11T10:00:00.000Z',
          },
          {
            'id': 'notification-2',
            'actor': {'name': 'Luis'},
            'type': 'new_personal_post',
            'postId': 'post-2',
            'message': 'published a new personal post',
            'createdAt': '2026-10-11T11:00:00.000Z',
          },
        ],
        'unreadCount': 2,
      };
    }
    if (path == '/api/community/v1/me/profile') {
      return {
        'profile': {
          'name': 'Ana Rivera',
          'userName': 'ana',
          'shortDescription': 'Connecting neighbors',
          'bio': 'Community volunteer',
          'location': 'Dénia',
          'accentColor': 'purple',
          'neonBordersEnabled': false,
          'neonBorderAnimation': 'breathing',
          'neonAnimationDurationSeconds': 7.5,
          'isPrivate': true,
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
            'communityShare': {'caption': 'Shared by the business'},
            'createdAt': '2026-10-01T10:00:00.000Z',
            'moderation': {
              'reason': 'Rules violation',
              'reviewedAt': '2026-10-02T10:00:00.000Z',
            },
          },
        ],
      };
    }
    if (path == '/api/community/v1/communities/community-1/category-order') {
      return {
        'order': ['category-1', 'all'],
      };
    }
    if (path == '/api/community/v1/communities/community-1/category-activity') {
      return {
        'totalUnreadCount': 4,
        'activity': [
          {'categoryId': 'category-1', 'unreadCount': 3},
          {'categoryId': 'category-2', 'unreadCount': 1},
        ],
      };
    }
    if (path.endsWith('/content-notification-preferences')) {
      return {
        'preferences': {
          'mode': 'selected',
          'selectedCategoryIds': ['category-1'],
          'contentTypes': ['posts'],
          'pushEnabled': true,
        },
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
            'isOnline': true,
            'lastActiveAt': '2026-10-05T09:55:00.000Z',
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
            'distanceKm': 1.25,
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
          'interactions30d': 1530,
          'monthlyRetentionRate': 42.5,
          'monetization': {
            'eligible': true,
            'currency': 'EUR',
            'reviewRequired': true,
            'evaluationPeriodStart': '2026-10-01T00:00:00.000Z',
            'evaluationPeriodEnd': '2026-11-01T00:00:00.000Z',
            'daysRemaining': 17,
            'payoutSetupComplete': false,
            'enrollment': {
              'requested': true,
              'status': 'approved',
              'accepted': true,
              'countryCode': 'ES',
              'currency': 'EUR',
              'termsVersion': '2026-10-15',
              'acceptedAt': '2026-10-02T10:00:00.000Z',
            },
            'currentTier': {
              'id': 'high_impact',
              'monthlyRewardCents': 5000,
              'memberTarget': 400,
              'monthlyActiveTarget': 150,
              'postsTarget': 40,
              'interactionsTarget': 150,
              'retentionTargetPercent': 25,
              'qualified': true,
            },
            'nextTier': null,
            'tiers': [],
            'history': [
              {
                'id': 'reward-1',
                'periodStart': '2026-09-01T00:00:00.000Z',
                'periodEnd': '2026-10-01T00:00:00.000Z',
                'metrics': {
                  'members': 1900,
                  'monthlyActive': 490,
                  'posts': 70,
                  'interactions': 1200,
                  'retentionPercent': 39.2,
                },
                'tierId': 'high_impact',
                'rewardCents': 5000,
                'currency': 'EUR',
                'status': 'pending_review',
              },
            ],
            'goodStanding': true,
          },
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
          'canInteract': false,
          'canShareToCommunities': true,
          'pinned': true,
          'canPin': true,
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
    if (path == '/api/community/v1/communities/category-suggestions') {
      return {
        'template': 'football',
        'editable': true,
        'categories': [
          {'key': 'general', 'name': 'General'},
          {'key': 'matches', 'name': 'Partidos'},
        ],
      };
    }
    if (path ==
        '/api/community/v1/communities/community-3/admin/news-access-application') {
      return {
        'application': {
          'id': 'application-3',
          'communityId': 'community-3',
          'status': 'pending',
          'message': body?['message'],
          'requestedAt': '2026-10-19T08:00:00.000Z',
        },
      };
    }
    if (path ==
        '/api/community/v1/communities/community-3/admin/news-access-application/cancel') {
      return {
        'application': {
          'id': 'application-3',
          'communityId': 'community-3',
          'status': 'cancelled',
          'requestedAt': '2026-10-19T08:00:00.000Z',
          'cancelledAt': '2026-10-19T09:00:00.000Z',
        },
      };
    }
    if (path ==
        '/api/community/v1/communities/community-1/admin/news-collect') {
      return {
        'collected': 2,
        'processed': 2,
        'pendingApproval': 1,
        'published': 0,
        'skipped': 1,
        'errors': 0,
      };
    }
    if (path == '/api/community/v1/posts/post-1/translation') {
      return {
        'translation': {
          'postId': 'post-1',
          'targetLanguage': body?['targetLanguage'],
          'translatedText': 'Reunión comunitaria',
          'cached': false,
        },
      };
    }
    if (path == '/api/community/v1/communities/community-1/about-translation') {
      return {
        'translation': {
          'communityId': 'community-1',
          'sourceLanguage': 'en',
          'targetLanguage': 'es',
          'translatedShortDescription': 'Resumen local',
          'translatedDescription': 'Descripción completa',
          'cached': false,
        },
      };
    }
    if (path == '/api/community/v1/pages/page-1/support-application') {
      return {
        'application': {
          'id': 'support-1',
          'pageId': 'page-1',
          ...?body,
          'status': 'pending',
          'requestedAt': '2026-10-16T10:00:00.000Z',
          'providerStatus': 'not_configured',
          'paymentsEnabled': false,
        },
      };
    }
    if (path.endsWith('/admin/rewards/request')) {
      return {
        'enrollment': {
          'requested': true,
          'status': 'pending',
          'countryCode': body?['countryCode'],
          'countryName': body?['countryName'],
          'contactEmail': body?['contactEmail'],
          'requestedAt': '2026-10-15T12:00:00.000Z',
        },
      };
    }
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
    if (path == '/api/community/v1/businesses/business-1/orders') {
      return {
        'order': {
          'id': 'order-1',
          'businessId': 'business-1',
          'orderNumber': 1042,
          'status': 'pending',
          'fulfillmentMethod': body?['fulfillmentMethod'],
          'subtotalCents': 900,
          'items': [
            {
              'productId': 'classic',
              'name': 'Classic burger',
              'quantity': 2,
              'unitPriceCents': 450,
              'totalCents': 900,
            },
          ],
          'createdAt': '2026-10-13T10:00:00.000Z',
        },
      };
    }
    if (path == '/api/community/v1/businesses/business-1/requests') {
      return {
        'request': {
          'id': 'request-1',
          'businessId': 'business-1',
          'requestNumber': 1043,
          'type': body?['type'],
          'status': 'pending',
          'serviceName': body?['serviceName'],
          'description': body?['description'],
          'preferredAt': body?['preferredAt'],
          'attachments': const [],
          'createdAt': '2026-10-13T12:00:00.000Z',
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
    if (path == '/api/community/v1/business-orders/order-1/status') {
      return {
        'order': {
          'id': 'order-1',
          'businessId': 'business-1',
          'orderNumber': 1042,
          'status': body?['status'],
          'fulfillmentMethod': 'delivery',
          'subtotalCents': 900,
          'items': const [],
          'createdAt': '2026-10-13T10:00:00.000Z',
        },
      };
    }
    if (path == '/api/community/v1/business-requests/request-1/status') {
      return {
        'request': {
          'id': 'request-1',
          'businessId': 'business-1',
          'requestNumber': 1043,
          'type': 'quote',
          'status': body?['status'],
          'serviceName': 'Garden maintenance',
          'quotedPriceCents': body?['quotedPriceCents'],
          'attachments': const [],
          'createdAt': '2026-10-13T12:00:00.000Z',
        },
      };
    }
    if (path == '/api/community/v1/businesses/business-1/request-settings') {
      return {
        'settings': {
          'businessId': 'business-1',
          'businessName': 'Jardines Michel',
          'acceptingRequests': body?['acceptingRequests'],
          'capabilities': body?['capabilities'],
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
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    lastPath = path;
    lastMethod = 'PUT';
    lastBody = body;
    if (path == '/api/community/v1/communities/community-1/category-order') {
      return {'order': body?['order'] ?? const <String>[]};
    }
    if (path == '/api/community/v1/communities/community-1/categories/order') {
      return {
        'categories': [
          for (final id in body?['categoryIds'] as List? ?? const [])
            {
              '_id': id,
              'communityId': 'community-1',
              'name': id == 'category-2' ? 'Events' : 'General',
              'icon': '💬',
            },
        ],
      };
    }
    if (path.endsWith('/content-notification-preferences')) {
      return {'preferences': body};
    }
    if (path.endsWith('/admin/rewards/enrollment')) {
      return {
        'enrollment': {
          'accepted': true,
          'countryCode': 'EC',
          'currency': 'USD',
          'termsVersion': '2026-10-15',
          'acceptedAt': '2026-10-15T12:00:00.000Z',
        },
      };
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    lastPath = path;
    lastMethod = 'DELETE';
    if (path == '/api/community/v1/communities/community-1/category-order') {
      return {
        'order': ['all', 'category-1'],
      };
    }
    return {'deleted': true};
  }
}

void main() {
  test('news post parser preserves attribution and original URL', () async {
    final repository = HttpCommunityRepository(apiClient: _NewsPostApiClient());
    final posts = await repository.listPosts('pilot-community');
    expect(posts.single.newsSource?.sourceName, 'Council');
    expect(
      posts.single.newsSource?.articleUrl,
      'https://publisher.example/article?ref=Original',
    );
    expect(posts.single.newsSource?.publishedAt, DateTime.utc(2026, 10, 19, 8));
  });

  test(
    'missing community preferences enable all categories without replacing saved choices',
    () async {
      final api = _PreferenceDefaultsApiClient();
      final repository = HttpCommunityRepository(apiClient: api);
      expect(
        (await repository.getCommunityContentNotificationPreferences(
          'community-1',
        )).mode,
        ContentNotificationMode.all,
      );
      for (final mode in ContentNotificationMode.values) {
        api.preferences = {
          'mode': mode.name,
          'selectedCategoryIds': ['news'],
          'pushEnabled': false,
        };
        final saved = await repository
            .getCommunityContentNotificationPreferences('community-1');
        expect(saved.mode, mode);
        expect(saved.selectedCategoryIds, ['news']);
        expect(saved.pushEnabled, isFalse);
      }
      api.preferences = {};
      expect(
        (await repository.getPersonContentNotificationPreferences(
          'person-1',
        )).mode,
        ContentNotificationMode.important,
      );
    },
  );
  test(
    'category activity and scoped notification preferences use dedicated endpoints',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final activity = await repository.getCategoryActivity('community-1');
      expect(activity.totalUnreadCount, 4);
      expect(activity.unreadByCategory['category-1'], 3);

      const preferences = ScopedNotificationPreferences(
        mode: ContentNotificationMode.selected,
        selectedCategoryIds: ['category-1'],
        contentTypes: ['posts'],
        pushEnabled: false,
      );
      final saved = await repository
          .updateCommunityContentNotificationPreferences(
            'community-1',
            preferences,
          );
      expect(
        api.lastPath,
        '/api/community/v1/communities/community-1/content-notification-preferences',
      );
      expect(api.lastBody?['mode'], 'selected');
      expect(saved.pushEnabled, isFalse);

      await repository.markCommunityPostsSeen('community-1', ['post-1']);
      expect(api.lastBody?['postIds'], ['post-1']);
    },
  );

  test('category order is loaded, saved and reset per community', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    expect(await repository.getCategoryOrder('community-1'), [
      'category-1',
      'all',
    ]);
    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/category-order',
    );

    expect(
      await repository.updateCategoryOrder('community-1', [
        'all',
        'category-1',
      ]),
      ['all', 'category-1'],
    );
    expect(api.lastBody, {
      'order': ['all', 'category-1'],
    });

    expect(await repository.resetCategoryOrder('community-1'), [
      'all',
      'category-1',
    ]);
    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/category-order',
    );
  });

  test('administrators can persist the shared category order', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final categories = await repository.reorderCategories('community-1', const [
      'category-2',
      'category-1',
    ]);

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/categories/order',
    );
    expect(api.lastBody?['categoryIds'], ['category-2', 'category-1']);
    expect(categories.map((item) => item.id), ['category-2', 'category-1']);
  });

  test('removed posts can be listed and restored with a reason', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final posts = await repository.listRemovedPosts('community-1');
    expect(posts.single.status, PostStatus.removed);
    expect(posts.single.moderationReason, 'Rules violation');
    expect(posts.single.reviewedAt, DateTime.utc(2026, 10, 2, 10));
    expect(posts.single.isCommunityShare, isTrue);
    expect(posts.single.shareCaption, 'Shared by the business');

    await repository.removePost(
      'community-1',
      'post-removed',
      reason: 'Not relevant to this community',
    );
    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/admin/posts/post-removed/remove',
    );
    expect(api.lastBody, {'reason': 'Not relevant to this community'});

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
      expect(profile.shortDescription, 'Connecting neighbors');
      expect(profile.bio, 'Community volunteer');
      expect(profile.accentColor, 'purple');
      expect(profile.neonBorderAnimation, NeonBorderAnimation.breathing);
      expect(profile.neonAnimationDurationSeconds, 7.5);
      expect(profile.isPrivate, isTrue);
      expect(await repository.isUsernameAvailable('available'), isTrue);
      expect(await repository.isUsernameAvailable('taken'), isFalse);

      await repository.updateEditableProfile(profile);
      expect(api.lastPath, '/api/community/v1/me/profile');
      expect(api.lastBody?['name'], 'Ana Rivera');
      expect(api.lastBody?['shortDescription'], 'Connecting neighbors');
      expect(api.lastBody?['accentColor'], 'purple');
      expect(api.lastBody?['neonBordersEnabled'], isFalse);
      expect(api.lastBody?['neonBorderAnimation'], 'breathing');
      expect(api.lastBody?['isPrivate'], isTrue);
      expect(api.lastBody?['neonAnimationDurationSeconds'], 7.5);
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
    expect(page.people.single.distanceKm, 1.25);
    expect(page.nextCursor, 'MjU');

    await repository.searchPeople(
      latitude: -1.43,
      longitude: -79.28,
      radiusKm: 10,
    );
    final nearbyUri = Uri.parse(api.lastPath!);
    expect(nearbyUri.queryParameters['latitude'], '-1.43');
    expect(nearbyUri.queryParameters['longitude'], '-79.28');
    expect(nearbyUri.queryParameters['radiusKm'], '10.0');
  });

  test('direct messaging uses private conversation endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final conversations = await repository.listDirectConversations();
    expect(conversations.single.otherUser.name, 'Ana');
    expect(conversations.single.unreadCount, 2);
    expect(conversations.single.isOnline, isTrue);
    expect(
      conversations.single.lastActiveAt,
      DateTime.parse('2026-10-05T09:55:00.000Z'),
    );

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

      await repository.createAdminInvitation('community-1', 'member-3');
      expect(
        api.lastPath,
        '/api/community/v1/communities/community-1/admin-invitations',
      );
      expect(api.lastBody, {'targetUserId': 'member-3'});

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
    expect(insights.interactions30d, 1530);
    expect(insights.monthlyRetentionRate, 42.5);
    expect(insights.monetization.currentTier?.id, 'high_impact');
    expect(insights.monetization.currentTier?.monthlyRewardCents, 5000);
    expect(insights.monetization.daysRemaining, 17);
    expect(insights.monetization.enrollment.countryCode, 'ES');
    expect(insights.monetization.history.single.status, 'pending_review');
    expect(insights.monetization.history.single.interactions, 1200);
    expect(insights.memberGrowth.last.members, 2043);
  });

  test('community owner accepts Ecuador reward pilot terms', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final enrollment = await repository.acceptCommunityRewardTerms(
      'community-1',
      countryCode: 'EC',
    );

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/admin/rewards/enrollment',
    );
    expect(api.lastBody, {'accepted': true});
    expect(enrollment.accepted, isTrue);
    expect(enrollment.currency, 'USD');
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

  test(
    'header border uses the existing community API and defaults off',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);
      var community = Community(
        id: 'community-1',
        name: 'Community',
        description: '',
        town: const Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'user-1',
        createdAt: DateTime.utc(2026),
        accentColor: 'purple',
      );
      for (final (enabled, expected) in <(bool?, bool)>[
        (null, false),
        (true, true),
        (null, true),
        (false, false),
      ]) {
        community = await repository.updateCommunity(
          community,
          town: community.town,
          name: community.name,
          description: community.description,
          visibility: community.visibility,
          approvalRequired: false,
          showWeather: false,
          links: [],
          businessServices: [],
          businessLocation: null,
          headerBorderEnabled: enabled,
        );
        expect(api.lastPath, '/api/community/v1/communities/community-1');
        expect(
          community.headerBorderEnabled,
          api.lastBody?['headerBorderEnabled'] == true,
        );
        expect(community.accentColor, 'purple');
        expect(community.headerBorderEnabled, expected);
        if (enabled != null) {
          expect(community.headerBorderEnabled, enabled);
        }
      }
    },
  );

  test('community member-directory privacy is sent and decoded', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    final community = Community(
      id: 'community-1',
      name: 'Community',
      description: '',
      town: const Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'user-1',
      createdAt: DateTime.utc(2026),
    );

    final updated = await repository.updateCommunity(
      community,
      town: community.town,
      name: community.name,
      description: community.description,
      visibility: community.visibility,
      approvalRequired: false,
      membersListVisible: false,
      showWeather: false,
      links: const [],
      businessServices: const [],
      businessLocation: null,
    );

    expect(api.lastBody?['membersListVisible'], isFalse);
    expect(updated.membersListVisible, isFalse);
  });

  test('page edits only send fields supported by the page type', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);
    const town = Town(id: 'town-1', name: 'Town X', countryCode: 'EC');
    final createdAt = DateTime.utc(2026, 1, 1);

    Future<void> update(
      Community community, {
      ProfileCategory? profileCategory,
      List<BusinessService> businessServices = const [],
      bool? published,
      String? accentColor,
      bool? neonBordersEnabled,
      NeonBorderAnimation? neonBorderAnimation,
      double? neonAnimationDurationSeconds,
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
      published: published,
      accentColor: accentColor,
      neonBordersEnabled: neonBordersEnabled,
      neonBorderAnimation: neonBorderAnimation,
      neonAnimationDurationSeconds: neonAnimationDurationSeconds,
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
    expect(api.lastBody?['accentColor'], 'teal');
    expect(api.lastBody?['neonBordersEnabled'], isFalse);

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
    expect(api.lastBody?['published'], isTrue);

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
      published: false,
      accentColor: 'rose',
      neonBordersEnabled: true,
      neonBorderAnimation: NeonBorderAnimation.aurora,
      neonAnimationDurationSeconds: 8.5,
    );
    expect(api.lastBody?['published'], isFalse);
    expect(api.lastBody?['accentColor'], 'rose');
    expect(api.lastBody?['neonBordersEnabled'], isTrue);
    expect(api.lastBody?['neonBorderAnimation'], 'aurora');
    expect(api.lastBody?['neonAnimationDurationSeconds'], 8.5);

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

    await repository.listNearbyCommunities(
      latitude: 40.5,
      longitude: -3.7,
      excludeTownId: 'town-1',
    );

    final uri = Uri.parse(api.lastPath!);
    expect(uri.path, '/api/community/v1/communities/nearby');
    expect(uri.queryParameters['latitude'], '40.5');
    expect(uri.queryParameters['longitude'], '-3.7');
    expect(uri.queryParameters['radiusKm'], '25.0');
    expect(uri.queryParameters['excludeTownId'], 'town-1');
  });

  test('business discovery sends location mode parameters', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.listLocalBusinesses(townId: 'town-1');
    var uri = Uri.parse(api.lastPath!);
    expect(uri.path, '/api/community/v1/communities');
    expect(
      uri.queryParameters['profileCategories'],
      'local_business,organization',
    );
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

      final communities = await repository.listCommunities(
        query: 'Town X',
        townId: 'town-1',
      );
      final communityUri = Uri.parse(api.lastPath!);
      expect(communityUri.path, '/api/community/v1/communities');
      expect(communityUri.queryParameters['q'], 'Town X');
      expect(communityUri.queryParameters['townId'], 'town-1');
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

  test('category suggestions preserve stable keys and language', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final suggestions = await repository.getCategorySuggestions(
      spaceType: CommunityType.community,
      subject: 'Fútbol',
      language: 'es',
    );

    expect(api.lastPath, '/api/community/v1/communities/category-suggestions');
    expect(api.lastBody?['subject'], 'Fútbol');
    expect(api.lastBody?['language'], 'es');
    expect(suggestions.template, 'football');
    expect(suggestions.categories[1].key, 'matches');
    expect(suggestions.categories[1].name, 'Partidos');
  });

  test('global community creation does not send a town', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final community = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Flutter Developers',
        description: 'Developers everywhere',
        visibility: CommunityVisibility.public,
        categoryNames: ['Technology'],
        scope: CommunityScope.global,
      ),
    );

    expect(api.lastBody?['scope'], 'global');
    expect(api.lastBody?.containsKey('townId'), isFalse);
    expect(community.scope, CommunityScope.global);
    expect(community.town.name, 'Everywhere');
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

  test(
    'business catalog and order flow preserve prices and quantities',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final catalog = await repository.getBusinessCatalog('business-1');
      expect(catalog.businessName, 'Burger House');
      expect(catalog.acceptingOrders, isTrue);
      expect(catalog.products.single.priceCents, 450);
      expect(catalog.products.single.quantityAvailable, 8);
      expect(catalog.products.single.variants.single.name, 'Medium · Blue');
      expect(catalog.products.single.variants.single.attributes['Size'], 'M');

      final order = await repository.createBusinessOrder(
        'business-1',
        const BusinessOrderInput(
          fulfillmentMethod: BusinessFulfillmentOption.delivery,
          deliveryAddress: 'Calle Principal',
          lines: [
            BusinessOrderLineInput(
              productId: 'classic',
              variantId: 'variant-medium-blue',
              quantity: 2,
            ),
          ],
        ),
      );
      expect(api.lastPath, '/api/community/v1/businesses/business-1/orders');
      expect(api.lastBody?['items'], [
        {
          'productId': 'classic',
          'variantId': 'variant-medium-blue',
          'quantity': 2,
        },
      ]);
      expect(order.orderNumber, 1042);
      expect(order.subtotalCents, 900);

      final accepted = await repository.updateBusinessOrderStatus(
        order.id,
        BusinessOrderStatus.accepted,
      );
      expect(api.lastPath, '/api/community/v1/business-orders/order-1/status');
      expect(api.lastBody?['status'], 'accepted');
      expect(accepted.status, BusinessOrderStatus.accepted);
    },
  );

  test(
    'business requests use contextual types and shared status APIs',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final settings = await repository.getBusinessRequestSettings(
        'business-1',
      );
      expect(settings.acceptingRequests, isTrue);
      expect(settings.capabilities, [
        BusinessRequestType.quote,
        BusinessRequestType.service,
      ]);

      final preferredAt = DateTime.utc(2026, 10, 20, 9);
      final request = await repository.createBusinessRequest(
        'business-1',
        BusinessRequestInput(
          type: BusinessRequestType.quote,
          serviceName: 'Garden maintenance',
          description: 'Trim the garden and clean the pool.',
          preferredAt: preferredAt,
          attachmentBlobNames: const ['request/photo.jpg'],
        ),
      );
      expect(api.lastPath, '/api/community/v1/businesses/business-1/requests');
      expect(api.lastBody?['type'], 'quote');
      expect(api.lastBody?['attachmentBlobNames'], ['request/photo.jpg']);
      expect(request.requestNumber, 1043);

      final quoted = await repository.updateBusinessRequestStatus(
        request.id,
        BusinessRequestStatus.quoted,
        quotedPriceCents: 7500,
      );
      expect(
        api.lastPath,
        '/api/community/v1/business-requests/request-1/status',
      );
      expect(api.lastBody?['status'], 'quoted');
      expect(quoted.quotedPriceCents, 7500);
    },
  );

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
    expect(post.canInteract, isFalse);
    expect(post.canShareToCommunities, isTrue);
    expect(post.pinned, isTrue);
    expect(post.canPin, isTrue);
  });

  test('pinning and unpinning use the dedicated post endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.setPostPinned('post-1', pinned: true);
    expect(api.lastPath, '/api/community/v1/posts/post-1/pin');
    expect(api.lastMethod, 'PUT');

    await repository.setPostPinned('post-1', pinned: false);
    expect(api.lastPath, '/api/community/v1/posts/post-1/pin');
    expect(api.lastMethod, 'DELETE');
  });

  test('hiding and restoring a post use the private user endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    await repository.setPostHidden('post-1', hidden: true);
    expect(api.lastPath, '/api/community/v1/me/hidden-posts/post-1');
    expect(api.lastMethod, 'PUT');

    await repository.setPostHidden('post-1', hidden: false);
    expect(api.lastPath, '/api/community/v1/me/hidden-posts/post-1');
    expect(api.lastMethod, 'DELETE');
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

  test('scoped post notifications retain their distinct types', () async {
    final repository = HttpCommunityRepository(
      apiClient: _RecordingApiClient(),
    );

    final feed = await repository.listNotifications();

    expect(feed.unreadCount, 2);
    expect(feed.items[0].type, CommunityNotificationType.newPost);
    expect(feed.items[1].type, CommunityNotificationType.newPersonalPost);
  });

  test('financial support applications stay separate from payments', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    expect(await repository.getFinancialSupportApplication('page-1'), isNull);
    final submitted = await repository.submitFinancialSupportApplication(
      'page-1',
      countryCode: 'EC',
      recipientType: 'community_project',
      purpose: 'Support community workshops and local activities.',
      contactEmail: 'project@example.com',
    );
    expect(api.lastPath, '/api/community/v1/pages/page-1/support-application');
    expect(submitted.status, 'pending');
    expect(submitted.paymentsEnabled, isFalse);

    final queue = await repository.listFinancialSupportApplications();
    expect(queue.single.pageName, 'Local Project');
    expect(queue.single.providerStatus, 'not_configured');

    await repository.reviewFinancialSupportApplication(
      'support-1',
      approve: true,
      note: 'Initial application approved',
    );
    expect(
      api.lastPath,
      '/api/community/v1/platform/support-applications/support-1',
    );
    expect(api.lastBody?['status'], 'approved');
  });

  test(
    'page administrator permissions use the owner-controlled endpoint',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      await repository.setPagePermissions(
        'page-1',
        'admin-1',
        messages: true,
        orders: false,
        services: true,
        analytics: false,
      );

      expect(
        api.lastPath,
        '/api/community/v1/communities/page-1/members/admin-1/page-permissions',
      );
      expect(api.lastBody, {
        'messages': true,
        'orders': false,
        'services': true,
        'analytics': false,
      });
    },
  );

  test('post translation sends the requested target language', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final translation = await repository.translatePost(
      'post-1',
      targetLanguage: 'es',
    );

    expect(api.lastPath, '/api/community/v1/posts/post-1/translation');
    expect(api.lastBody, {'targetLanguage': 'es'});
    expect(translation.postId, 'post-1');
    expect(translation.targetLanguage, 'es');
    expect(translation.translatedText, 'Reunión comunitaria');
    expect(translation.cached, isFalse);
  });

  test('Local News settings and runs use administrator endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final sources = await repository.listLocalNewsSources();
    expect(sources.single.name, 'Local Gazette');
    expect(sources.single.authorizedForAutoPublish, isTrue);

    final settings = await repository.getLocalNewsSettings('community-1');
    expect(settings.enabled, isTrue);
    expect(settings.subscriptionTier, 'pro');
    expect(settings.monthlyLimit, 60);
    expect(settings.plans[1].tier, 'pro');
    expect(settings.plans[1].priceEur, 4.99);

    await repository.updateLocalNewsSettings(
      'community-1',
      enabled: true,
      sourceIds: const ['source-1'],
      categoryIds: const ['category-1'],
      language: 'es',
      approvalMode: 'manual',
    );
    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/admin/news-settings',
    );

    final articles = await repository.listLocalNewsArticles('community-1');
    expect(articles.single.status, 'pending_approval');

    final result = await repository.runLocalNewsNow('community-1');
    expect(result.processed, 2);
    expect(result.pendingApproval, 1);
    expect(result.skipped, 1);
  });

  test(
    'Local News settings map access, usage, last run and application',
    () async {
      final api = _RecordingApiClient();
      final repository = HttpCommunityRepository(apiClient: api);

      final settings = await repository.getLocalNewsSettings('community-2');
      expect(settings.entitled, isTrue);
      expect(settings.isPilot, isTrue);
      expect(settings.subscriptionTier, 'free');
      expect(settings.monthlyLimit, 60);
      expect(settings.access?.dailyLimit, 2);
      expect(settings.usage.monthlyUsed, 5);
      expect(settings.usage.todayUsed, 1);
      expect(settings.usage.dailyLimit, 2);
      expect(settings.lastRun?.status, 'partial');
      expect(settings.lastRun?.trigger, 'scheduler');
      expect(settings.lastRun?.sourceErrors, 1);
      expect(settings.lastRun?.finishedAt, DateTime.utc(2026, 10, 19, 8));
      expect(settings.lastRun?.errorReason, 'sources_unavailable');
      final dashboard = settings.dashboard!;
      expect(dashboard.status, 'awaiting_approval');
      expect(
        dashboard.nextCollectionAt,
        DateTime.utc(2026, 10, 19, 21, 16, 31),
      );
      expect(dashboard.nextCollectionAt!.isUtc, isTrue);
      expect(dashboard.quotaResetsAt, DateTime.utc(2026, 10, 20));
      expect(dashboard.timezone, 'UTC');
      expect(dashboard.pendingApproval, 2);
      expect(dashboard.todayUsed, 1);
      expect(dashboard.publishedToday, 0);
      expect(dashboard.dailyLimitReached, isTrue);
      expect(dashboard.lastRun, isNull);
      expect(settings.application?.isApproved, isTrue);
      expect(settings.application?.reviewNote, 'Welcome');

      final legacy = await repository.getLocalNewsSettings('community-1');
      expect(legacy.dashboard, isNull);
      expect(legacy.access, isNull);
      expect(legacy.entitled, isTrue, reason: 'older responses still work');
      expect(legacy.lastRun, isNull);
      expect(legacy.application, isNull);
    },
  );

  test('Local News visibility comes from the server capability flag', () async {
    final repository = HttpCommunityRepository(
      apiClient: _RecordingApiClient(),
    );
    final pilot = await repository.getCommunity('pilot-community');
    final other = await repository.getCommunity('other-community');
    expect(pilot.canManageLocalNews, isTrue);
    expect(other.myRole, CommunityRole.admin);
    expect(
      other.canManageLocalNews,
      isFalse,
      reason: 'missing flag means hidden',
    );
  });

  test('Local News access applications use owner endpoints', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final submitted = await repository.submitLocalNewsAccessApplication(
      'community-3',
      message: 'Town news please',
    );
    expect(
      api.lastPath,
      '/api/community/v1/communities/community-3/admin/news-access-application',
    );
    expect(api.lastBody, {'message': 'Town news please'});
    expect(submitted.isPending, isTrue);
    expect(submitted.message, 'Town news please');

    final cancelled = await repository.cancelLocalNewsAccessApplication(
      'community-3',
    );
    expect(
      api.lastPath,
      '/api/community/v1/communities/community-3/admin/news-access-application/cancel',
    );
    expect(cancelled.status, 'cancelled');
  });

  test('About translation maps both description fields', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final translation = await repository.translateCommunityAbout(
      'community-1',
      targetLanguage: 'es',
    );

    expect(
      api.lastPath,
      '/api/community/v1/communities/community-1/about-translation',
    );
    expect(api.lastBody, {'targetLanguage': 'es'});
    expect(translation.translatedShortDescription, 'Resumen local');
    expect(translation.translatedDescription, 'Descripción completa');
    expect(translation.targetLanguage, 'es');
  });
}
