import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/features/community/community_invitations_page.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class _OwnershipSafetyRepository extends DemoCommunityRepository {
  String? transferTarget;
  String? respondedTransfer;
  String? safetyReason;
  String? safetyIssue;
  bool invitationResponded = false;

  @override
  Future<List<CommunityMember>> listMembers(
    String communityId, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'admin-2',
      communityId: communityId,
      role: CommunityRole.admin,
      status: MembershipStatus.active,
      joinedAt: DateTime.utc(2026),
      name: 'Test administrator',
    ),
  ];

  @override
  Future<void> createOwnershipTransfer(
    String communityId,
    String targetUserId,
  ) async {
    transferTarget = targetUserId;
  }

  @override
  Future<List<CommunityInvitation>> listMyCommunityInvitations() async =>
      invitationResponded
      ? []
      : [
          CommunityInvitation(
            id: 'transfer-1',
            communityId: 'community-1',
            type: 'ownership_transfer',
            status: 'pending',
            expiresAt: DateTime.now().add(const Duration(days: 7)),
            createdAt: DateTime.now(),
            communityName: 'Test community',
          ),
        ];

  @override
  Future<void> respondToCommunityInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    respondedTransfer = accept ? invitationId : null;
    invitationResponded = true;
  }

  @override
  Future<void> contactWicchuSafety(
    String communityId,
    String reason, {
    required String issue,
  }) async {
    safetyReason = reason;
    safetyIssue = issue;
  }
}

class _AdminInvitationRepository extends DemoCommunityRepository {
  String? invitedUserId;
  String? acceptedInvitationId;
  bool invitationResponded = false;

  @override
  Future<List<CommunityMember>> listMembers(
    String communityId, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'member-2',
      communityId: communityId,
      role: CommunityRole.member,
      status: MembershipStatus.active,
      joinedAt: DateTime.utc(2026),
      name: 'Future administrator',
    ),
  ];

  @override
  Future<void> createAdminInvitation(
    String communityId,
    String targetUserId,
  ) async {
    invitedUserId = targetUserId;
  }

  @override
  Future<List<CommunityInvitation>> listMyCommunityInvitations() async =>
      invitationResponded
          ? []
          : [
              CommunityInvitation(
                id: 'admin-invite-1',
                communityId: 'community-1',
                type: 'admin_invitation',
                status: 'pending',
                expiresAt: DateTime.now().add(const Duration(days: 7)),
                createdAt: DateTime.now(),
                communityName: 'Test community',
              ),
            ];

  @override
  Future<void> respondToCommunityInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    acceptedInvitationId = accept ? invitationId : null;
    invitationResponded = true;
  }
}

void main() {
  testWidgets('owner sends an acceptance-based administrator invitation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _AdminInvitationRepository();
    final community = (await repository.listJoinedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: MemberManagementPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Future administrator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite as administrator'));
    await tester.pumpAndSettle();
    expect(find.textContaining('only after accepting'), findsOneWidget);
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();

    expect(repository.invitedUserId, 'member-2');
    expect(
      find.text('Administrator invitation sent. The member must accept it.'),
      findsOneWidget,
    );
  });

  testWidgets('member accepts administrator invitation from Invitations', (
    tester,
  ) async {
    final repository = _AdminInvitationRepository();
    await tester.pumpWidget(
      MaterialApp(home: MyCommunityInvitationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The owner invited you to become an administrator of this space.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(repository.acceptedInvitationId, 'admin-invite-1');
  });

  testWidgets('owner sends an acceptance-based ownership transfer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _OwnershipSafetyRepository();
    final community = (await repository.listJoinedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: MemberManagementPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test administrator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer ownership'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must accept the transfer'), findsOneWidget);
    await tester.tap(find.text('Send transfer'));
    await tester.pumpAndSettle();

    expect(repository.transferTarget, 'admin-2');
    expect(
      find.text('Ownership transfer sent. The administrator must accept it.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invited administrator accepts ownership from Invitations', (
    tester,
  ) async {
    final repository = _OwnershipSafetyRepository();
    await tester.pumpWidget(
      MaterialApp(home: MyCommunityInvitationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The owner invited you to take ownership of this space.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repository.respondedTransfer, 'transfer-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('space owner contacts Wicchu Safety instead of self-reporting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _OwnershipSafetyRepository();
    final community = (await repository.listJoinedCommunities()).first;

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

    expect(find.text('Contact Wicchu Safety'), findsOneWidget);
    expect(find.text('Report community'), findsNothing);
    await tester.tap(find.text('Contact Wicchu Safety'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'I need help resolving an ownership concern.',
    );
    await tester.tap(find.text('Send to Wicchu Safety'));
    await tester.pumpAndSettle();

    expect(repository.safetyIssue, 'other');
    expect(
      repository.safetyReason,
      'I need help resolving an ownership concern.',
    );
    expect(find.text('Request sent to Wicchu Safety'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
