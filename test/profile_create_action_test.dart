import 'package:flutter/material.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('personal header creates as self in dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = DemoCommunityRepository();
      final profile = await repository.getProfile();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          home: MemberProfilePage(userId: profile.id, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('personal-profile-create-post'));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
      expect(find.byKey(const ValueKey('profile-first-post')), findsOneWidget);
      expect(find.text('Tip'), findsNothing);
      expect(find.text('Commun.'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CreatePostPage>(find.byType(CreatePostPage))
            .personalProfile,
        isTrue,
      );
      expect(find.text('My profile'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await repository.createPersonalPost(
        const CreatePostInput(categoryId: 'personal', text: 'My first post'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          home: MemberProfilePage(
            key: const ValueKey('with-post'),
            userId: profile.id,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(button, findsOneWidget);
      expect(find.byKey(const ValueKey('profile-first-post')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('visitors do not get a personal create action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(
          userId: 'other',
          repository: DemoCommunityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('personal-profile-create-post')),
      findsNothing,
    );
  });
  testWidgets('page menu composer targets the selected page', (tester) async {
    final repository = DemoCommunityRepository();
    final page = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Creator page',
        description: '',
        town: Town(id: 'town-1', name: 'Town', countryCode: 'ES'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.creator,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(community: page, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('space-profile-create-post')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('community-profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Create post'));
    await tester.pumpAndSettle();
    final composer = tester.widget<CreatePostPage>(find.byType(CreatePostPage));
    expect(composer.personalProfile, isFalse);
    expect(composer.community.id, page.id);
    expect(find.text(page.name), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
