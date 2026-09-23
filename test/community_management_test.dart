import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/http_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/post_card.dart';

class AttentionRepository extends DemoCommunityRepository {
  AdminAttentionSummary summary = const AdminAttentionSummary();
  bool fail = false;
  @override
  Future<AdminAttentionSummary> getAdminAttention(String communityId) async {
    if (fail) throw Exception('Unable to load');
    return summary;
  }
}

class RulesApi extends AuthenticatedApiClient {
  Map<String, dynamic>? sent;
  String? lastPath;
  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    sent = body;
    lastPath = path;
    return {
      'rule': {'id': 'rule-1', ...?body},
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => patch(path, body: body);
  @override
  Future<Map<String, dynamic>> delete(String path) async {
    lastPath = path;
    return {};
  }
}

void main() {
  test(
    'rule edits use dedicated endpoints and preserve rule identity',
    () async {
      final api = RulesApi();
      final repository = HttpCommunityRepository(apiClient: api);
      final rule = await repository.createRule(
        'community-1',
        title: 'Respect',
        description: 'Be kind',
        position: 0,
      );
      expect(api.lastPath, '/api/community/v1/communities/community-1/rules');
      expect(rule.id, 'rule-1');
      await repository.updateRule('community-1', rule, position: 2);
      expect(
        api.lastPath,
        '/api/community/v1/communities/community-1/rules/rule-1',
      );
      expect(api.sent, {'position': 2});
      await repository.deleteRule('community-1', rule.id);
      expect(
        api.lastPath,
        '/api/community/v1/communities/community-1/rules/rule-1',
      );
    },
  );

  testWidgets(
    'attention hides zero queues and never reports success on error',
    (tester) async {
      final repository = AttentionRepository();
      final community = (await repository.listJoinedCommunities()).first;
      Future<void> show() async {
        await tester.pumpWidget(
          MaterialApp(
            home: AdminDashboardPage(
              key: UniqueKey(),
              community: community,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show();
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.text('Posts awaiting approval'), findsNothing);
      repository.summary = const AdminAttentionSummary(pendingPosts: 3);
      await show();
      expect(find.text('Posts awaiting approval'), findsOneWidget);
      expect(find.text('Promotion requests'), findsNothing);
      expect(find.text('All caught up'), findsNothing);
      repository.fail = true;
      await show();
      expect(find.text('All caught up'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('community profile defaults to posts using the shared card', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final community = (await repository.listJoinedCommunities()).first;
    final category = (await repository.listCategories(community.id)).first;
    await repository.createPost(
      community.id,
      CreatePostInput(categoryId: category.id, text: 'A local update'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings opens the shared rule editor and saves a new rule', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunitySettingsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Community rules'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Community rules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Be respectful');
    await tester.enterText(
      find.byType(TextField).last,
      'Respect your neighbors',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Be respectful'), findsOneWidget);
    final updated = await repository.listRules(community.id);
    expect(updated.rules.last.title, 'Be respectful');
    expect(updated.rules.last.description, 'Respect your neighbors');
  });
}
