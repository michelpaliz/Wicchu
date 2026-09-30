import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/community_invitations_page.dart';

void main() {
  for (final scenario in [
    (CommunityVisibility.public, CommunityRole.member, true),
    (CommunityVisibility.private, CommunityRole.member, false),
    (CommunityVisibility.private, CommunityRole.admin, true),
    (CommunityVisibility.public, null, false),
  ]) {
    testWidgets('invite visibility for ${scenario.$1} ${scenario.$2}', (
      tester,
    ) async {
      final repository = DemoCommunityRepository();
      final original = (await repository.listJoinedCommunities()).first;
      final community = Community(
        id: original.id,
        name: original.name,
        description: original.description,
        town: original.town,
        visibility: scenario.$1,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
        myRole: scenario.$2,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text('Edit community'),
        scenario.$2 == CommunityRole.admin ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('Community information'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(const ValueKey('community-information-content')),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final invite = find.byKey(const ValueKey('community-header-invite'));
      expect(invite, scenario.$3 ? findsOneWidget : findsNothing);
      if (scenario.$2 == CommunityRole.admin) {
        await tester.tap(invite);
        await tester.pumpAndSettle();
        expect(find.byType(CommunityInvitationsPage), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
