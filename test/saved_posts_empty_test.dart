import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/features/community/post_collection_page.dart';

void main() {
  testWidgets('saved posts empty state opens browsing', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PostCollectionPage(
          title: 'Saved posts',
          repository: DemoCommunityRepository(),
          loadPosts: () async => [],
          onBrowsePosts: () => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You haven’t saved any posts yet'), findsOneWidget);
    await tester.ensureVisible(find.text('Explore posts'));
    await tester.tap(find.text('Explore posts'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
