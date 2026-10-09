import "package:wicchu/domain/community_repository.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'package:wicchu/features/community/post_rules_review_page.dart';

void main() {
  testWidgets('step one switches group only after reviewing its rules', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final original = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Original group',
        description: 'Original',
        town: Town(id: 'town-1', name: 'Town', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Another group',
        description: 'Another',
        town: Town(id: 'town-1', name: 'Town', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['News'],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          community: original,
          repository: repository,
          categories: await repository.listCategories(original.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Another group'));
    await tester.pumpAndSettle();
    expect(find.byType(PostRulesReviewPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Original group'), findsOneWidget);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Another group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Another group'), findsOneWidget);
    expect(find.text('Original group'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
