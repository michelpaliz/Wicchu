import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/widgets/visible_post_observer.dart';

class _ActivityRepository extends DemoCommunityRepository {
  bool failFirstSeen = false;
  int? seenFailureStatus;
  bool failPreferences = false;
  int preferenceWrites = 0;
  int seenRequests = 0;
  final batches = <List<String>>[];
  Community? communityOverride;

  @override
  Future<Community> getCommunity(String id) async =>
      communityOverride ?? await super.getCommunity(id);

  @override
  Future<ScopedNotificationPreferences>
  getCommunityContentNotificationPreferences(String id) {
    if (failPreferences) throw StateError('Preferences unavailable');
    return super.getCommunityContentNotificationPreferences(id);
  }

  @override
  Future<ScopedNotificationPreferences>
  updateCommunityContentNotificationPreferences(
    String id,
    ScopedNotificationPreferences preferences,
  ) {
    preferenceWrites++;
    return super.updateCommunityContentNotificationPreferences(id, preferences);
  }

  @override
  Future<List<CommunityPost>> listPosts(
    String id, {
    String? categoryId,
    String? query,
    String? sort,
  }) async => [
    for (var i = 0; i < 12; i++)
      CommunityPost(
        id: '$id-post-$i',
        communityId: id,
        categoryId: 'category-${i % 2}',
        authorId: i == 11 ? 'current-user' : 'neighbor',
        authorName: 'Neighbor',
        text: 'Post $i',
        status: i == 10 ? PostStatus.pendingApproval : PostStatus.published,
        createdAt: DateTime(2026),
      ),
  ];

  @override
  Future<void> markCommunityPostsSeen(String id, List<String> postIds) async {
    seenRequests++;
    if (seenFailureStatus case final status?) {
      throw ApiException('Rejected', statusCode: status);
    }
    if (failFirstSeen && seenRequests == 1) throw StateError('Offline');
    batches.add([...postIds]);
    await super.markCommunityPostsSeen(id, postIds);
  }
}

void main() {
  for (final role in [
    CommunityRole.member,
    CommunityRole.admin,
    CommunityRole.owner,
  ]) {
    testWidgets(
      '$role can configure and reopen personal category notifications from membership menu',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _ActivityRepository();
        final original = (await repo.listJoinedCommunities()).first;
        final community = Community(
          id: original.id,
          name: original.name,
          description: original.description,
          town: original.town,
          visibility: original.visibility,
          createdBy: original.createdBy,
          createdAt: original.createdAt,
          myRole: role,
        );
        repo.communityOverride = community;
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(community: community, repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('community-role-badge')));
        await tester.pumpAndSettle();
        expect(find.text('Category notifications'), findsOneWidget);
        await tester.tap(find.text('Category notifications'));
        await tester.pumpAndSettle();
        expect(
          find.text('Choose the content you want to hear about.'),
          findsOneWidget,
        );
        final categorySwitch = find.byKey(
          const ValueKey('category-notification-category-0'),
        );
        await tester.ensureVisible(categorySwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(categorySwitch).value, isTrue);
        await tester.tap(categorySwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(categorySwitch).value, isFalse);
        expect(repo.preferenceWrites, 0);
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        final saved = await repo.getCommunityContentNotificationPreferences(
          community.id,
        );
        expect(saved.mode, ContentNotificationMode.selected);
        expect(
          saved.selectedCategoryIds,
          hasLength((await repo.listCategories(community.id)).length - 1),
        );
        expect(saved.selectedCategoryIds, isNot(contains('category-0')));
        expect(repo.preferenceWrites, 1);
        await tester.tap(find.byKey(const ValueKey('community-role-badge')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Category notifications'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(categorySwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(categorySwitch).value, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'failed preferences load never opens an editor with default settings',
    (tester) async {
      final repo = _ActivityRepository()..failPreferences = true;
      final community = (await repo.listJoinedCommunities()).first;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(community: community, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customize-category-order')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(repo.preferenceWrites, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'demo activity counts published posts by others and marks read idempotently per community',
    () async {
      final repo = _ActivityRepository();
      final first = await repo.getCategoryActivity('a');
      expect(first.totalUnreadCount, 10);
      expect(first.unreadByCategory, {'category-0': 5, 'category-1': 5});
      await repo.markCommunityPostsSeen('a', [
        'a-post-0',
        'a-post-0',
        'b-post-1',
      ]);
      expect((await repo.getCategoryActivity('a')).totalUnreadCount, 9);
      expect((await repo.getCategoryActivity('b')).totalUnreadCount, 10);
      await repo.markCommunityPostsSeen('a', ['a-post-0']);
      expect((await repo.getCategoryActivity('a')).totalUnreadCount, 9);
    },
  );

  test('announcement flag survives creation and edit in demo', () async {
    final repo = DemoCommunityRepository();
    final community = (await repo.listJoinedCommunities()).first;
    final post = await repo.createPost(
      community.id,
      const CreatePostInput(
        categoryId: 'category-0',
        text: 'Alert',
        importantAnnouncement: true,
      ),
    );
    expect(post.importantAnnouncement, isTrue);
    final edited = await repo.updatePost(
      post.id,
      const CreatePostInput(
        categoryId: 'category-0',
        text: 'Alert edited',
        importantAnnouncement: true,
      ),
    );
    expect(edited.importantAnnouncement, isTrue);
  });

  testWidgets(
    'cached off-screen posts remain unread until visible, and report once',
    (tester) async {
      final seen = <int>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: ListView.builder(
                controller: controller,
                scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                itemCount: 8,
                itemBuilder: (_, i) => VisiblePostObserver(
                  key: ValueKey(i),
                  onSeen: () => seen.add(i),
                  child: SizedBox(height: 200, child: Text('Post $i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen, [0, 1]);
      controller.jumpTo(600);
      await tester.pumpAndSettle();
      expect(seen, containsAll([3, 4]));
      expect(seen, isNot(contains(7)));
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(seen.where((id) => id == 0).length, 1);
    },
  );

  testWidgets(
    'community retries failed read acknowledgement without repeated successful writes',
    (tester) async {
      final repo = _ActivityRepository()..failFirstSeen = true;
      final community = (await repo.listJoinedCommunities()).first;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(community: community, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.seenRequests, 0);
      await tester.tap(find.text('News').first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.seenRequests, 1);
      expect(repo.batches, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.seenRequests, 2);
      expect(repo.batches, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      expect(repo.seenRequests, 2);
      expect(repo.batches.single.length, lessThan(12));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('community does not retry rejected read acknowledgements', (
    tester,
  ) async {
    final repo = _ActivityRepository()..seenFailureStatus = 400;
    final community = (await repo.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(community: community, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.seenRequests, 0);
    await tester.tap(find.text('News').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(repo.seenRequests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
