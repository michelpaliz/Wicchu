import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class _Repository extends DemoCommunityRepository {
  _Repository(
    ProfileCategory? category,
    CommunityRole viewerRole, {
    this.fail = false,
  }) : community = Community(
         id: 'role-test',
         name: 'Test space',
         description: '',
         town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
         visibility: CommunityVisibility.public,
         createdBy: 'owner',
         createdAt: DateTime(2026),
         myRole: viewerRole,
         type: category != null
             ? CommunityType.publicProfile
             : CommunityType.community,
         profileCategory: category,
       );
  final Community community;
  final bool fail;
  CommunityRole role = CommunityRole.member;
  int writes = 0;
  int invitations = 0;
  @override
  Future<void> createAdminInvitation(String id, String userId) async {
    invitations++;
    if (fail) throw Exception('Unable to invite administrator');
  }

  @override
  Future<Community> getCommunity(String id) async => community;
  @override
  Future<List<CommunityMember>> listMembers(
    String id, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'owner',
      communityId: id,
      name: 'Owner name',
      role: CommunityRole.owner,
      status: MembershipStatus.active,
      joinedAt: DateTime(2026),
    ),
    CommunityMember(
      userId: 'target',
      communityId: id,
      name: 'Target name',
      role: role,
      status: MembershipStatus.active,
      joinedAt: DateTime(2026),
    ),
  ];
  @override
  Future<void> setMemberRole(
    String id,
    String userId,
    CommunityRole value,
  ) async {
    writes++;
    if (fail) throw Exception('Unable to update role');
    role = value;
  }
}

void main() {
  for (final category in <ProfileCategory?>[null, ...ProfileCategory.values]) {
    for (final fail in [false, true]) {
      testWidgets('role change category=$category failure=$fail', (
        tester,
      ) async {
        final repository = _Repository(
          category,
          CommunityRole.owner,
          fail: fail,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              community: repository.community,
              repository: repository,
              screen: CommunityScreen.members,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('member-role-owner')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('member-role-target')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Invite as administrator'));
        await tester.pumpAndSettle();
        expect(repository.writes, 0);
        await tester.tap(find.widgetWithText(FilledButton, 'Send invitation'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.writes, 0);
        expect(repository.invitations, 1);
        expect(repository.role, CommunityRole.member);
        expect(
          find.text(
            'Administrator invitation sent. The member must accept it.',
          ),
          fail ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
      'admin can set moderator but cannot invite administrators category=$category',
      (tester) async {
        final repository = _Repository(category, CommunityRole.admin);
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              community: repository.community,
              repository: repository,
              screen: CommunityScreen.members,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('member-role-target')));
        await tester.pumpAndSettle();
        expect(find.text('Invite as administrator'), findsNothing);
        await tester.tap(find.text('Moderator'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(repository.writes, 0);
        await tester.tap(find.byKey(const ValueKey('member-role-target')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Moderator'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
        await tester.pumpAndSettle();
        expect(repository.writes, 1);
        expect(repository.invitations, 0);
        expect(repository.role, CommunityRole.moderator);
        expect(find.text('Moderator'), findsOneWidget);
      },
    );
    testWidgets('ordinary viewer cannot change roles category=$category', (
      tester,
    ) async {
      final repository = _Repository(category, CommunityRole.member);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: repository.community,
            repository: repository,
            screen: CommunityScreen.members,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-role-target')), findsNothing);
      expect(repository.writes, 0);
    });
  }
}
