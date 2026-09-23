import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/http_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
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
  bool ignore = false;
  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    sent = body;
    return {
      'community': {'id': 'test', ...?body, if (ignore) 'rules': null},
    };
  }
}

void main() {
  test(
    'rules are sent in order, cleared explicitly, and ignored updates fail',
    () async {
      final community =
          (await DemoCommunityRepository().listJoinedCommunities()).first;
      final api = RulesApi();
      final repository = HttpCommunityRepository(apiClient: api);
      Future<Community> save(List<CommunityRule>? rules) =>
          repository.updateCommunity(
            community,
            name: community.name,
            description: community.description,
            visibility: community.visibility,
            approvalRequired: false,
            rules: rules,
          );
      final result = await save(const [
        CommunityRule(title: 'Respect', description: 'Be kind'),
        CommunityRule(title: 'Local', description: ''),
      ]);
      expect(result.rules.map((r) => r.title), ['Respect', 'Local']);
      expect((api.sent!['rules'] as List).length, 2);
      await save([]);
      expect(api.sent!['rules'], isEmpty);
      await save(null);
      expect(api.sent!.containsKey('rules'), isFalse);
      api.ignore = true;
      await expectLater(save([]), throwsA(isA<ApiException>()));
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
    await repository.createPost(community.id, CreatePostInput(
      categoryId: category.id, text: 'A local update'));
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

  testWidgets('rule editor validates title and saves a new rule', (
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
    await tester.scrollUntilVisible(find.text('Add rule'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Add rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a rule title'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Be respectful');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Respect your neighbors',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Be respectful'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Save changes'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final updated = (await repository.listJoinedCommunities()).firstWhere(
      (c) => c.id == community.id,
    );
    expect(updated.rules.last.title, 'Be respectful');
    expect(updated.rules.last.description, 'Respect your neighbors');
  });
}
