import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

void main() {
  testWidgets('administrator can add a useful link and persist it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoCommunityRepository();
    final communities = await repository.listJoinedCommunities();
    final community = communities.firstWhere(
      (c) => c.myRole == CommunityRole.owner || c.myRole == CommunityRole.admin,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: repository,
          screen: CommunityScreen.links,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Town website');
    await tester.enterText(
      find.byType(TextFormField).last,
      'https://example.com/town',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      (await repository.getCommunity(
        community.id,
      )).links.any((l) => l.url == 'https://example.com/town'),
      isTrue,
    );
    expect(find.text('Town website'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
