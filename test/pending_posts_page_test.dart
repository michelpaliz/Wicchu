import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/pending_posts_page.dart';

class ReviewRepository extends DemoCommunityRepository {
  final pending = List.generate(
    2,
    (index) => CommunityPost(
      id: 'pending-$index',
      communityId: 'town-x-community',
      categoryId: 'category-0',
      authorId: 'author',
      authorName: 'Reviewer test',
      text:
          'Request $index\n\n${List.filled(30, 'A paragraph to review.').join('\n\n')}',
      status: PostStatus.pendingApproval,
      createdAt: DateTime.now(),
    ),
  );
  String? decided;
  bool? approved;
  @override
  Future<List<CommunityPost>> listPendingPosts(String communityId) async =>
      List.of(pending);
  @override
  Future<void> moderatePost(
    String communityId,
    String postId, {
    required bool approve,
    String? reason,
  }) async {
    decided = postId;
    approved = approve;
    pending.removeWhere((post) => post.id == postId);
  }
}

void main() {
  testWidgets(
    'reviews selected request with fixed actions and advances after decision',
    (tester) async {
      final repository = ReviewRepository();
      final community = await repository.getCommunity('town-x-community');
      await tester.pumpWidget(
        MaterialApp(
          home: PendingPostsPage(community: community, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 posts'), findsOneWidget);
      expect(find.text('Approve').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Next post'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 posts'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(repository.decided, 'pending-1');
      expect(repository.approved, isTrue);
      expect(find.text('1 of 1 post'), findsOneWidget);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(repository.decided, 'pending-0');
      expect(repository.approved, isFalse);
      expect(find.text('No posts need approval'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    },
  );
}
