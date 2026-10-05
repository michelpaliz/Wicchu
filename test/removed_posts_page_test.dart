import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/removed_posts_page.dart';

class _RemovedPostsRepository extends DemoCommunityRepository {
  String? restoredPostId;
  String? restorationReason;

  @override
  Future<List<CommunityPost>> listRemovedPosts(String communityId) async => [
    CommunityPost(
      id: 'removed-1',
      communityId: communityId,
      categoryId: 'general',
      authorId: 'member-1',
      authorName: 'User Testing',
      text: 'A removed community update',
      status: PostStatus.removed,
      createdAt: DateTime.utc(2026, 10, 1),
      moderationReason: 'Incorrect information',
    ),
  ];

  @override
  Future<void> restorePost(
    String communityId,
    String postId, {
    required String reason,
  }) async {
    restoredPostId = postId;
    restorationReason = reason;
  }
}

void main() {
  testWidgets('admin restores a removed post with an audit reason', (
    tester,
  ) async {
    final repository = _RemovedPostsRepository();
    final community = (await repository.listJoinedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: RemovedPostsPage(community: community, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A removed community update'), findsOneWidget);
    expect(find.textContaining('Incorrect information'), findsOneWidget);
    await tester.tap(find.text('Restore post'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Decision reviewed');
    await tester.pump();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(repository.restoredPostId, 'removed-1');
    expect(repository.restorationReason, 'Decision reviewed');
    expect(find.text('Post restored'), findsOneWidget);
  });
}
