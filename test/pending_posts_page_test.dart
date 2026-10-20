import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      shareCaption: 'Shared introduction $index',
      text:
          'Request $index\n\n${List.filled(30, 'A paragraph to review.').join('\n\n')}',
      status: PostStatus.pendingApproval,
      createdAt: DateTime.now(),
    ),
  );
  String? decided;
  bool? approved;
  String? rejectionReason;
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
    rejectionReason = reason;
    pending.removeWhere((post) => post.id == postId);
  }
}

class NewsReviewRepository extends ReviewRepository {
  final news = [
    CommunityPost(
      id: 'news-1', communityId: 'town-x-community', categoryId: 'category-0',
      authorId: 'author', text: '## Local update\n\nA short factual summary.\n\nSource: Council\nhttps://publisher.example/story?ref=Original',
      status: PostStatus.pendingApproval, createdAt: DateTime.now(),
      newsSource: LocalNewsAttribution(
        sourceName: 'Council', articleUrl: 'https://publisher.example/story?ref=Original',
        publishedAt: DateTime.utc(2026, 10, 19),
      ),
    ),
  ];

  @override
  Future<List<CommunityPost>> listPendingPosts(String communityId) async => List.of(news);

  @override
  Future<void> moderatePost(String communityId, String postId, {required bool approve, String? reason}) async {
    decided = postId;
    approved = approve;
    news.removeWhere((post) => post.id == postId);
  }
}

void main() {
  testWidgets('news review opens the exact publisher URL and remains manual', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    String? opened;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') {
        opened = (call.arguments as Map)['url']?.toString();
        return true;
      }
      return false;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final repository = NewsReviewRepository();
    final community = await repository.getCommunity('town-x-community');
    await tester.pumpWidget(MaterialApp(home: PendingPostsPage(community: community, repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Publisher: Council'), findsOneWidget);
    expect(find.text('Read original article'), findsOneWidget);
    expect(find.textContaining('Source: Council'), findsNothing);
    await tester.tap(find.text('Read original article'));
    await tester.pumpAndSettle();
    expect(opened, 'https://publisher.example/story?ref=Original');
    expect(repository.decided, isNull);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(repository.decided, 'news-1');
    expect(repository.approved, isTrue);
  });

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
      expect(
        find.textContaining('Shared introduction 0', findRichText: true),
        findsWidgets,
      );
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
      expect(find.text('Reject post'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Not relevant to this community');
      await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(repository.decided, 'pending-0');
      expect(repository.approved, isFalse);
      expect(repository.rejectionReason, 'Not relevant to this community');
      expect(find.text('No posts need approval'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    },
  );
}
