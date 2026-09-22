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
    if (path.contains('/posts/')) {
      return {
        'post': {
          'id': 'post-1',
          'communityId': 'community-1',
          'categoryId': 'category-1',
          'text': 'Community meeting',
          'status': 'pendingApproval',
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
    if (path == '/api/community/v1/towns/resolve') {
      return {
        'town': {
          'id': 'town-echeandia',
          'name': 'Echeandía',
          'countryCode': 'EC',
        },
      };
    }
    return {
      'community': {'id': 'community-1', 'name': body?['name']},
    };
  }
}

void main() {
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

  test('post detail accepts the pending approval status', () async {
    final api = _RecordingApiClient();
    final repository = HttpCommunityRepository(apiClient: api);

    final post = await repository.getPost('post-1');

    expect(api.lastPath, '/api/community/v1/posts/post-1');
    expect(post.status, PostStatus.pendingApproval);
  });
}
