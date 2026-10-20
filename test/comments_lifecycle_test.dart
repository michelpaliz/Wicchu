import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/comments_sheet.dart';

class _DeferredRepository extends DemoCommunityRepository {
  final loading = Completer<List<Comment>>();
  final saving = Completer<Comment>();
  final rules = Completer<CommunityRules>();
  bool delayRules = false;
  int saves = 0;
  @override
  Future<List<Comment>> listComments(String postId) => loading.future;
  @override
  Future<Comment> createComment(
    String postId,
    String text, {
    String? parentCommentId,
  }) {
    saves++;
    return saving.future;
  }

  @override
  Future<CommunityRules> listRules(String communityId) =>
      delayRules ? rules.future : super.listRules(communityId);
}

void main() {
  final post = CommunityPost(
    id: 'post',
    communityId: 'community',
    categoryId: 'news',
    authorId: 'author',
    text: 'Post',
    status: PostStatus.published,
    destinationType: 'personal',
    createdAt: DateTime(2026),
  );
  final comment = Comment(
    id: 'comment',
    postId: 'post',
    authorId: 'author',
    text: 'Hello',
    createdAt: DateTime(2026),
  );
  Widget screen(_DeferredRepository repository, ValueChanged<int> changed) =>
      MaterialApp(
        home: Scaffold(
          body: PostComments(
            repository: repository,
            post: post,
            onCountChanged: changed,
          ),
        ),
      );

  testWidgets('closing comments ignores a late list response', (tester) async {
    final repository = _DeferredRepository();
    final counts = <int>[];
    await tester.pumpWidget(screen(repository, counts.add));
    await tester.pumpWidget(const SizedBox.shrink());
    repository.loading.complete([comment]);
    await tester.pumpAndSettle();
    expect(counts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing during submission does not notify a disposed screen', (
    tester,
  ) async {
    final repository = _DeferredRepository()..loading.complete([]);
    final counts = <int>[];
    await tester.pumpWidget(screen(repository, counts.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pump();
    expect(repository.saves, 1);
    counts.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    repository.saving.complete(comment);
    await tester.pumpAndSettle();
    expect(counts, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('closing during rules check prevents a later submission', (
    tester,
  ) async {
    final repository = _DeferredRepository()
      ..loading.complete([])
      ..delayRules = true;
    await tester.pumpWidget(screen(repository, (_) {}));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    repository.rules.complete(
      const CommunityRules(
        rules: [],
        rulesVersion: 0,
        acceptedRulesVersion: 0,
        acceptanceRequired: false,
        canManage: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });
}
