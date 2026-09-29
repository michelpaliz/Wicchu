import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/create_post_page.dart';

Community space(
  CommunityType type,
  CommunityRole? role, [
  ProfileCategory? category,
]) => Community(
  id: 'space',
  name: 'A page',
  description: '',
  town: const Town(id: 'town', name: 'Town', countryCode: 'ES'),
  visibility: CommunityVisibility.public,
  createdBy: 'owner',
  createdAt: DateTime(2026),
  type: type,
  profileCategory: category,
  myRole: role,
);

void main() {
  test('only owners/admins can publish on every public page type', () {
    for (final category in ProfileCategory.values) {
      for (final role in [null, ...CommunityRole.values]) {
        expect(
          space(CommunityType.publicProfile, role, category).canPublish,
          role == CommunityRole.owner || role == CommunityRole.admin,
        );
      }
    }
    expect(
      space(CommunityType.community, CommunityRole.member).canPublish,
      isTrue,
    );
    expect(space(CommunityType.community, null).canPublish, isFalse);
  });

  testWidgets('direct composer entry blocks a business follower', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          community: space(
            CommunityType.publicProfile,
            CommunityRole.member,
            ProfileCategory.localBusiness,
          ),
          repository: DemoCommunityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('You do not have permission to publish in this space.'),
      findsOneWidget,
    );
    expect(find.text('Publish'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
