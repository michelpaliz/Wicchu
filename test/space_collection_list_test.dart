import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/space_collection_list.dart';

void main() {
  testWidgets('spaces filter by type and use follower/member labels', (
    tester,
  ) async {
    final spaces = [
      for (final business in [false, true])
        Community(
          id: business ? 'business' : 'group',
          name: business ? 'Garden services' : 'Neighbors',
          description: '',
          town: const Town(id: 'town', name: 'Denia', countryCode: 'ES'),
          visibility: CommunityVisibility.public,
          createdBy: 'owner',
          createdAt: DateTime(2026),
          memberCount: 2,
          myRole: business ? CommunityRole.member : CommunityRole.owner,
          type: business
              ? CommunityType.publicProfile
              : CommunityType.community,
          profileCategory: business ? ProfileCategory.localBusiness : null,
        ),
    ];
    Community? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpaceCollectionList(
            spaces: spaces,
            onOpen: (space) => opened = space,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    expect(find.text('2 members'), findsOneWidget);
    expect(find.text('2 followers'), findsOneWidget);
    expect(find.byTooltip('Following'), findsOneWidget);
    expect(find.byTooltip('Owner'), findsOneWidget);
    await tester.tap(find.text('Public profiles'));
    await tester.pumpAndSettle();
    expect(find.text('Neighbors'), findsNothing);
    await tester.tap(find.text('Garden services'));
    expect(opened?.id, 'business');
    await tester.tap(find.text('Communities'));
    await tester.pumpAndSettle();
    expect(find.text('Garden services'), findsNothing);
    expect(find.text('Neighbors'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
