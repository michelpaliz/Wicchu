import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/community/comments_sheet.dart';

void main() {
  testWidgets('nested replies stay visible and replying focuses the composer', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final community = (await repository.listJoinedCommunities()).first;
    final category = (await repository.listCategories(community.id)).first;
    final post = await repository.createPost(
      community.id,
      CreatePostInput(categoryId: category.id, text: 'Test post'),
    );
    final root = await repository.createComment(post.id, 'Root message');
    final reply = await repository.createComment(
      post.id,
      'First reply',
      parentCommentId: root.id,
    );
    await repository.createComment(
      post.id,
      'Nested reply',
      parentCommentId: reply.id,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPostComments(context, repository, post),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Nested reply'), findsNothing);
    await tester.tap(find.text('View 2 replies'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nested reply'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nested reply'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Nested reply')).dx, greaterThan(tester.getTopLeft(find.text('First reply')).dx));
    await tester.tap(find.text('Reply').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.text('Write a reply'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
