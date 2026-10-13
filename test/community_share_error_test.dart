import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/http_community_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sharing references the source without supplying author identity or privacy overrides',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        AuthenticatedApiClient.accessTokenKey: 'test-token',
      });
      final repository = HttpCommunityRepository(
        apiClient: AuthenticatedApiClient(
          client: MockClient((request) async {
            expect(
              request.url.path,
              endsWith('/posts/anonymous-post/community-shares'),
            );
            expect(jsonDecode(request.body), {
              'caption': 'Introduction',
              'destinations': [
                {'communityId': 'echeandia', 'categoryId': 'general'},
              ],
            });
            return http.Response(
              jsonEncode({
                'results': [
                  {'communityId': 'echeandia', 'status': 'pending_approval'},
                ],
              }),
              200,
            );
          }),
        ),
      );
      await repository.sharePersonalPostToCommunities(
        'anonymous-post',
        categoryByCommunity: {'echeandia': 'general'},
        caption: 'Introduction',
      );
    },
  );
  test('sharing rejection preserves community rules requirement', () async {
    FlutterSecureStorage.setMockInitialValues({
      AuthenticatedApiClient.accessTokenKey: 'test-token',
    });
    final repository = HttpCommunityRepository(
      apiClient: AuthenticatedApiClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'results': [
                {
                  'communityId': 'echeandia',
                  'status': 'failed',
                  'code': 'SHARE_FAILED',
                  'message':
                      'Accept the latest community rules before contributing',
                },
              ],
            }),
            422,
          ),
        ),
      ),
    );
    await expectLater(
      repository.sharePersonalPostToCommunities(
        'business-post',
        categoryByCommunity: {'echeandia': 'business'},
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 422)
            .having(
              (error) => error.message,
              'reason',
              'Accept the latest community rules before contributing',
            ),
      ),
    );
  });
}
