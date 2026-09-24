import 'package:wicchu/features/community/create_post_page.dart';
import 'package:wicchu/widgets/feed_filter_bar.dart';
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

class CategoryApi extends AuthenticatedApiClient {
  Map<String, dynamic>? sent;
  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    sent = body;
    return {
      'category': {'id': 'category-1', 'communityId': 'community-1', ...?body},
    };
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => post(path, body: body);
}

void main() {
  test(
    'category requests send icons and omit an unchanged optional icon',
    () async {
      final api = CategoryApi();
      final repository = HttpCommunityRepository(apiClient: api);
      final category = await repository.createCategory(
        'community-1',
        name: 'News',
        icon: '📰',
      );
      expect(api.sent?['icon'], '📰');
      expect(category.icon, '📰');
      final updated = await repository.updateCategory(
        'community-1',
        category,
        name: 'Events',
        description: '',
        icon: '📅',
      );
      expect(api.sent?['icon'], '📅');
      expect(updated.icon, '📅');
      await repository.updateCategory(
        'community-1',
        updated,
        name: 'Events',
        description: 'Local',
      );
      expect(api.sent!.containsKey('icon'), isFalse);
    },
  );

  testWidgets(
    'category editor validates and saves without losing the category',
    (tester) async {
      final repository = DemoCommunityRepository();
      final community = (await repository.listJoinedCommunities()).first;
      final category = (await repository.listCategories(community.id)).first;
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryManagementPage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(category.name).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-icon-📰')));
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a category name.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Neighborhood');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Edit category'), findsNothing);
      expect(
        (await repository.listCategories(
          community.id,
        )).firstWhere((item) => item.id == category.id).name,
        'Neighborhood',
      );
      expect(
        (await repository.listCategories(
          community.id,
        )).firstWhere((item) => item.id == category.id).icon,
        '📰',
      );
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(
      tester
          .widget<FeedFilterBar>(find.byType(FeedFilterBar).first)
          .selectedIndex,
      0,
    );
    expect(tester.widget<FeedFilterBar>(find.byType(FeedFilterBar).first).labels.length, 3);
    await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    expect(find.text('No media yet'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsWidgets);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostPage), findsOneWidget);
    expect(
      tester.widget<CreatePostPage>(find.byType(CreatePostPage)).community.id,
      community.id,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      tester
          .widget<FeedFilterBar>(find.byType(FeedFilterBar).first)
          .selectedIndex,
      1,
    );
    await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FeedFilterBar>(find.byType(FeedFilterBar).first)
          .selectedIndex,
      2,
    );
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
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Enter a rule title.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Be respectful');
    await tester.enterText(
      find.byType(TextField).last,
      'Respect your neighbors',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Be respectful'), findsOneWidget);
    final updated = await repository.listRules(community.id);
    expect(updated.rules.last.title, 'Be respectful');
    expect(updated.rules.last.description, 'Respect your neighbors');
  });
}
