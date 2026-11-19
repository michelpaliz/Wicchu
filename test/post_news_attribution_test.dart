import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_card.dart';

void main() {
  CommunityPost newsPost(PostStatus status) => CommunityPost(
    id: 'news-post',
    communityId: 'community',
    categoryId: 'news',
    authorId: 'author',
    text: 'Local update',
    status: status,
    createdAt: DateTime.utc(2026, 10, 19),
    newsSource: const LocalNewsAttribution(
      sourceName: 'Local publisher',
      articleUrl: 'https://publisher.example/article',
    ),
  );

  Widget card(CommunityPost post, {bool showNewsAttribution = false}) =>
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: post,
            category: 'News',
            icon: '📰',
            community: 'Community',
            author: 'Member',
            time: 'Now',
            text: post.text,
            showNewsAttribution: showNewsAttribution,
          ),
        ),
      );

  testWidgets('public posts do not show the original article action', (
    tester,
  ) async {
    await tester.pumpWidget(card(newsPost(PostStatus.published)));

    expect(find.text('Read original article'), findsNothing);
    expect(find.text('Publisher: Local publisher'), findsNothing);
  });

  testWidgets('review previews can show the original article source', (
    tester,
  ) async {
    await tester.pumpWidget(
      card(newsPost(PostStatus.pendingApproval), showNewsAttribution: true),
    );

    expect(find.text('Read original article'), findsOneWidget);
    expect(find.text('Publisher: Local publisher'), findsOneWidget);
  });
}
