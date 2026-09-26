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
    final nested = await repository.createComment(
      post.id,
      'Nested reply',
      parentCommentId: reply.id,
    );
    final third = await repository.createComment(
      post.id,
      'Third level',
      parentCommentId: nested.id,
    );
    final fourth = await repository.createComment(
      post.id,
      'Fourth level',
      parentCommentId: third.id,
    );
    await repository.createComment(
      post.id,
      'Fifth level',
      parentCommentId: fourth.id,
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
    await tester.tap(find.text('View 5 replies'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nested reply'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nested reply'), findsOneWidget);
    double left(String text) => tester.getTopLeft(find.text(text)).dx;
    for (final text in [
      'Nested reply',
      'Third level',
      'Fourth level',
      'Fifth level',
    ]) {
      expect(left(text), left('First reply'));
    }
    await tester.scrollUntilVisible(
      find.text('Fifth level'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Reply').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.text('Write a reply'), findsOneWidget);
    final send = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Send comment',
    );
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.enterText(
      find.byType(TextField),
      'Reply to the deepest comment',
    );
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
