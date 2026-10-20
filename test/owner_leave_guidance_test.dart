import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/features/chat/direct_chat_pages.dart';

class _Repository extends DemoCommunityRepository {
  _Repository(this.hasAdmin, this.viewerRole);
  final bool hasAdmin;
  final CommunityRole viewerRole;
  int leaves = 0;
  String? inboxPageId;
  @override
  Future<List<Community>> listManagedCommunities() async => [community];
  @override
  Future<List<DirectConversation>> listDirectConversations({
    String? pageId,
  }) async {
    inboxPageId = pageId;
    return [];
  }

  late final community = Community(
    id: 'test',
    name: 'Community',
    description: '',
    town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
    visibility: CommunityVisibility.public,
    createdBy: 'owner',
    createdAt: DateTime(2026),
    myRole: viewerRole,
  );
  @override
  Future<Community> getCommunity(String id) async => community;
  @override
  Future<List<CommunityMember>> listMembers(
    String id, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'other',
      communityId: id,
      name: 'Other member',
      role: hasAdmin ? CommunityRole.admin : CommunityRole.member,
      status: MembershipStatus.active,
      joinedAt: DateTime(2026),
    ),
  ];
  @override
  Future<void> leaveCommunity(String id) async {
    leaves++;
  }
}

void main() {
  testWidgets('community messages move from the header into the options menu', (
    tester,
  ) async {
    final repository = _Repository(true, CommunityRole.owner);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: repository.community,
          repository: repository,
          screen: CommunityScreen.information,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('information-message')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const ValueKey('community-profile-menu')),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Leave'), findsNothing);
    expect(find.byTooltip('Share'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Manage community'), findsOneWidget);
    expect(find.text('Community messages'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    await tester.tap(find.text('Community messages'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationListPage), findsOneWidget);
    expect(repository.inboxPageId, repository.community.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('community options are grouped and role-aware for admins', (
    tester,
  ) async {
    final repository = _Repository(true, CommunityRole.admin);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: repository.community,
          repository: repository,
          screen: CommunityScreen.information,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));

    expect(inSheet('Community options'), findsOneWidget);
    expect(inSheet('Administration'), findsOneWidget);
    expect(inSheet('Manage community'), findsOneWidget);
    expect(inSheet('Community messages'), findsOneWidget);
    expect(inSheet('Notifications'), findsOneWidget);
    expect(inSheet('Edit community'), findsOneWidget);
    expect(inSheet('Contact Wicchu Safety'), findsOneWidget);
    expect(inSheet('Leave community'), findsOneWidget);
    expect(inSheet('Step down as administrator'), findsOneWidget);
    expect(inSheet('Report community'), findsNothing);

    await tester.scrollUntilVisible(
      inSheet('Step down as administrator'),
      200,
      scrollable: find
          .descendant(of: sheet, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(inSheet('Step down as administrator'));
    await tester.pumpAndSettle();
    expect(find.text('Step down as administrator?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('member options hide administration actions', (tester) async {
    final repository = _Repository(true, CommunityRole.member);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: repository.community,
          repository: repository,
          screen: CommunityScreen.information,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));

    expect(inSheet('Community options'), findsOneWidget);
    expect(inSheet('Share'), findsOneWidget);
    expect(inSheet('Invite people'), findsOneWidget);
    expect(inSheet('Useful links'), findsOneWidget);
    expect(inSheet('Media'), findsOneWidget);
    expect(inSheet('Administration'), findsNothing);
    expect(inSheet('Edit community'), findsNothing);
    expect(inSheet('Contact Wicchu Safety'), findsNothing);
    expect(inSheet('Leave community'), findsOneWidget);
    expect(inSheet('Report community'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final hasAdmin in [false, true]) {
    testWidgets('owner leave guides to management hasAdmin=$hasAdmin', (
      tester,
    ) async {
      final repository = _Repository(hasAdmin, CommunityRole.owner);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: repository.community,
            repository: repository,
            screen: CommunityScreen.information,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      final leave = find.descendant(
        of: sheet,
        matching: find.text('Leave community'),
      );
      await tester.scrollUntilVisible(
        leave,
        200,
        scrollable: find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(
        find.text(
          hasAdmin
              ? 'Transfer ownership before leaving.'
              : 'Invite a member as administrator first.',
        ),
        findsOneWidget,
      );
      expect(repository.leaves, 0);
      await tester.tap(
        find.text(hasAdmin ? 'Choose an administrator' : 'Choose a member'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MemberManagementPage), findsOneWidget);
      expect(repository.leaves, 0);
    });
  }
  testWidgets('administrator can leave normally', (tester) async {
    final repository = _Repository(true, CommunityRole.admin);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: repository.community,
          repository: repository,
          screen: CommunityScreen.information,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final leave = find.descendant(
      of: sheet,
      matching: find.text('Leave community'),
    );
    await tester.scrollUntilVisible(
      leave,
      200,
      scrollable: find
          .descendant(of: sheet, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.text('Leave this community?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Leave community'));
    await tester.pumpAndSettle();
    expect(repository.leaves, 1);
  });
}
