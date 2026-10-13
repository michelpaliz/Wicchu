import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_card.dart';

void main() {
  testWidgets('pinned publications show a badge and can be unpinned', (
    tester,
  ) async {
    bool? requestedState;
    final post = CommunityPost(
      id: 'post-1',
      communityId: 'community-1',
      categoryId: 'general',
      authorId: 'user-1',
      text: 'Pinned update',
      status: PostStatus.published,
      createdAt: DateTime.utc(2026, 10, 13),
      ownedByMe: true,
      pinned: true,
      canPin: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: '💬',
            community: 'Wicchu',
            author: 'Owner',
            time: 'Now',
            text: post.text,
            post: post,
            onPinnedChanged: (pinned) async => requestedState = pinned,
          ),
        ),
      ),
    );

    expect(find.text('Pinned publication'), findsOneWidget);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin publication'), findsOneWidget);
    expect(find.text('Remove it from the top of its category'), findsOneWidget);

    await tester.tap(find.text('Unpin publication'));
    await tester.pumpAndSettle();
    expect(requestedState, isFalse);
  });
}
