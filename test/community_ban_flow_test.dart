import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class _BanFlowRepository extends DemoCommunityRepository {
  MembershipStatus memberStatus = MembershipStatus.active;
  String? action;
  String? publicReason;
  String? internalNote;
  DateTime? expiresAt;
  String? appealReason;

  @override
  Future<List<CommunityMember>> listMembers(
    String communityId, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'member-1',
      communityId: communityId,
      role: CommunityRole.member,
      status: memberStatus,
      joinedAt: DateTime.utc(2026),
      name: 'Test member',
    ),
  ];

  @override
  Future<void> setMemberAccess(
    String communityId,
    String userId, {
    required String action,
    String? reason,
    String? internalNote,
    DateTime? expiresAt,
  }) async {
    this.action = action;
    publicReason = reason;
    this.internalNote = internalNote;
    this.expiresAt = expiresAt;
  }

  @override
  Future<void> appealCommunityBan(String communityId, String reason) async {
    appealReason = reason;
  }
}

void main() {
  testWidgets('admin can unban a member directly from the member list', (
    tester,
  ) async {
    final repository = _BanFlowRepository()
      ..memberStatus = MembershipStatus.banned;
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

    await tester.tap(find.text('Unban'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unban').last);
    await tester.pumpAndSettle();

    expect(repository.action, 'unban');
    expect(find.text('Member unbanned'), findsOneWidget);
  });

  testWidgets('admin ban form separates member reason and internal note', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _BanFlowRepository();
    final original = (await repository.listJoinedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: MemberManagementPage(community: original, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ban member'));
    await tester.pumpAndSettle();

    expect(find.text('Reason shown to member'), findsOneWidget);
    expect(find.text('Internal moderator note (optional)'), findsOneWidget);
    expect(find.text('Ban duration'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Repeated harassment');
    await tester.enterText(fields.at(1), 'Warnings documented by moderators');
    await tester.tap(find.text('Permanent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 days').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ban member').last);
    await tester.pumpAndSettle();

    expect(repository.action, 'ban');
    expect(repository.publicReason, 'Repeated harassment');
    expect(repository.internalNote, 'Warnings documented by moderators');
    expect(repository.expiresAt, isNotNull);
    expect(
      repository.expiresAt!.isAfter(
        DateTime.now().add(const Duration(days: 6)),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('banned member sees reason and can appeal to Wicchu Safety', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _BanFlowRepository();
    final original = (await repository.listJoinedCommunities()).first;
    final community = Community(
      id: original.id,
      name: original.name,
      description: original.description,
      town: original.town,
      visibility: original.visibility,
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      membershipStatus: MembershipStatus.banned,
      banPublicReason: 'Repeated harassment',
      banExpiresAt: DateTime.now().add(const Duration(days: 7)),
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

    expect(find.text('Your community access is restricted'), findsOneWidget);
    expect(find.textContaining('Repeated harassment'), findsOneWidget);
    expect(find.text('Request Wicchu Safety review'), findsOneWidget);
    expect(find.text('Join'), findsNothing);

    await tester.tap(find.text('Request Wicchu Safety review'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Please review the context of this decision.',
    );
    await tester.tap(find.text('Submit appeal'));
    await tester.pumpAndSettle();

    expect(
      repository.appealReason,
      'Please review the context of this decision.',
    );
    expect(find.text('Your appeal was sent to Wicchu Safety.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
