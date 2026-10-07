import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/widgets/feed_filter_bar.dart';

void main() {
  testWidgets('description expands and administration opens filtered members', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoCommunityRepository();
    final original = (await repository.listJoinedCommunities()).first;
    final community = Community(
      id: original.id,
      name: original.name,
      shortDescription: List.filled(
        3,
        'News, events and stories from our local community.',
      ).join(' '),
      description: List.filled(
        10,
        'News, events and stories from our local community.',
      ).join(' '),
      town: original.town,
      visibility: original.visibility,
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      myRole: CommunityRole.member,
      memberCount: original.memberCount,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: repository,
          screen: CommunityScreen.information,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(community.description), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(community.shortDescription)).maxLines,
      2,
    );
    await tester.tap(
      find.byKey(const ValueKey('community-description-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text(community.shortDescription)).maxLines,
      isNull,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('community-description-toggle')),
    );
    await tester.tap(
      find.byKey(const ValueKey('community-description-toggle')),
    );
    await tester.pumpAndSettle();
    final admins = find.byKey(
      const ValueKey('information-administration-entry'),
    );
    await tester.scrollUntilVisible(
      admins,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(admins);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FeedFilterBar>(find.byType(FeedFilterBar)).selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
