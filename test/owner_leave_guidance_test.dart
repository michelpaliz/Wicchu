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
  testWidgets(
    'information actions are in the app bar and owner opens the space inbox',
    (tester) async {
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
      for (final key in [
        'information-message',
        'information-invite',
        'community-profile-menu',
      ]) {
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byKey(ValueKey(key)),
          ),
          findsOneWidget,
        );
      }
      expect(
        tester.getCenter(find.byKey(const ValueKey('information-invite'))).dx,
        lessThan(
          tester
              .getCenter(find.byKey(const ValueKey('information-message')))
              .dx,
        ),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('information-message'))).dx,
        lessThan(
          tester
              .getCenter(find.byKey(const ValueKey('community-profile-menu')))
              .dx,
        ),
      );
      expect(find.byTooltip('Leave'), findsNothing);
      expect(find.byTooltip('Share'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('information-message')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationListPage), findsOneWidget);
      expect(repository.inboxPageId, repository.community.id);
      expect(tester.takeException(), isNull);
    },
  );
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
      await tester.tap(find.text('Leave community'));
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
    await tester.tap(find.text('Leave community'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this community?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Leave community'));
    await tester.pumpAndSettle();
    expect(repository.leaves, 1);
  });
}
