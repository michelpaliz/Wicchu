import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/community_invitations_page.dart';

class _InviteRepository extends DemoCommunityRepository {
  Community? current;
  @override
  Future<Community> getCommunity(String id) async =>
      current ?? await super.getCommunity(id);
}

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
      final repository = _InviteRepository();
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
      repository.current = community;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-profile-menu')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('community-header-invite')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('public-profile-message')),
        findsNothing,
      );
      if (scenario.$2 != null) {
        expect(
          find.byKey(const ValueKey('space-profile-create-post')),
          findsNothing,
        );
        expect(find.byTooltip('Search posts'), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsOneWidget);
      expect(
        find.text('Create post'),
        scenario.$2 != null ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Community messages'),
        scenario.$2 != null ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Notifications'),
        scenario.$2 != null ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Manage community'),
        scenario.$2 == CommunityRole.admin ? findsOneWidget : findsNothing,
      );
      final invite = find.text('Invite people');
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
