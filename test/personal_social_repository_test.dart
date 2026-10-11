import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/http_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';

class _Api extends AuthenticatedApiClient {
  String path = '';
  Map<String, dynamic>? body;

  Map<String, dynamic> get _personalPost => {
    'id': 'post-1',
    'communityId': null,
    'categoryId': null,
    'destinationType': 'personal',
    'visibility': 'public',
    'author': {'id': 'creator', 'name': 'Creator'},
    'text': 'Public update',
    'status': 'published',
    'createdAt': '2026-10-11T10:00:00.000Z',
  };

  @override
  Future<Map<String, dynamic>> get(String value) async {
    path = value;
    if (value.contains('/platform/reports')) {
      return {
        'reports': [
          {
            'id': 'report-1',
            'targetType': 'post',
            'targetId': 'post-1',
            'reporter': {'name': 'Reporter'},
            'targetUser': {'name': 'Creator'},
            'category': 'spam',
            'reason': 'Repeated advertising',
            'status': 'pending',
            'createdAt': '2026-10-11T10:00:00.000Z',
          },
        ],
      };
    }
    if (value.endsWith('/followers')) {
      return {
        'users': [
          {'id': 'follower', 'name': 'Follower', 'userName': 'follower'},
        ],
        'nextCursor': 'next',
      };
    }
    return {
      'user': {
        'id': 'creator',
        'name': 'Creator',
        'userName': 'creator',
        'shortDescription': 'Independent local journalist',
        'neonBordersEnabled': true,
        'neonBorderAnimation': 'aurora',
        'neonAnimationDurationSeconds': 8,
        'postCount': 1,
        'communityCount': 0,
        'followerCount': 4,
        'followingCount': 2,
        'followedByMe': true,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> put(
    String value, {
    Map<String, dynamic>? body,
  }) async {
    path = value;
    return {'following': true, 'followerCount': 5};
  }

  @override
  Future<Map<String, dynamic>> delete(String value) async {
    path = value;
    return {'following': false, 'followerCount': 4};
  }

  @override
  Future<Map<String, dynamic>> post(
    String value, {
    Map<String, dynamic>? body,
  }) async {
    path = value;
    this.body = body;
    if (value.endsWith('/community-shares')) {
      return {
        'results': [
          {'communityId': 'community-1', 'status': 'published'},
          {'communityId': 'community-2', 'status': 'pending_approval'},
        ],
      };
    }
    return {'post': _personalPost};
  }
}

void main() {
  test('personal follow profile and paginated lists map API state', () async {
    final api = _Api();
    final repository = HttpCommunityRepository(apiClient: api);

    final profile = await repository.getMemberProfile('creator');
    expect(profile.followedByMe, isTrue);
    expect(profile.shortDescription, 'Independent local journalist');
    expect(profile.neonBordersEnabled, isTrue);
    expect(profile.neonBorderAnimation, NeonBorderAnimation.aurora);
    expect(profile.neonAnimationDurationSeconds, 8);
    expect(profile.followerCount, 4);
    expect(await repository.followUser('creator'), 5);
    expect(await repository.unfollowUser('creator'), 4);
    final followers = await repository.listFollowers('creator');
    expect(followers.users.single.userName, 'follower');
    expect(followers.nextCursor, 'next');
  });

  test(
    'personal posts and canonical multi-community shares use new APIs',
    () async {
      final api = _Api();
      final repository = HttpCommunityRepository(apiClient: api);
      const input = CreatePostInput(
        categoryId: 'personal',
        text: 'Public update',
      );

      final post = await repository.createPersonalPost(input);
      expect(post.isPersonal, isTrue);
      expect(api.path, '/api/community/v1/me/posts');

      final results = await repository.sharePersonalPostToCommunities(
        post.id,
        categoryByCommunity: {'community-1': 'general', 'community-2': 'news'},
        caption: 'For local readers',
      );
      expect(results.where((item) => item.succeeded), hasLength(2));
      expect(api.body?['caption'], 'For local readers');
      expect(api.body?['destinations'], hasLength(2));
    },
  );

  test('personal post reports remain actionable in Wicchu Safety', () async {
    final repository = HttpCommunityRepository(apiClient: _Api());

    final reports = await repository.listPlatformReports();

    expect(reports.single.targetType, PlatformReportTargetType.post);
    expect(reports.single.targetName, 'Creator');
    expect(reports.single.communityId, isEmpty);
  });
}
