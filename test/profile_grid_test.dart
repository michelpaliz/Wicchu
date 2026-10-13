import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/post_collection_page.dart';
import 'package:wicchu/widgets/profile_post_grid.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/theme/wicchu_icons.dart';

void main() {
  testWidgets('personal profiles show only posts and media tabs', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final community = (await repository.listJoinedCommunities()).first;
    final category = (await repository.listCategories(community.id)).first;
    final saved = await repository.createPost(
      community.id,
      CreatePostInput(categoryId: category.id, text: 'Saved project'),
    );
    await repository.setPostSaved(saved.id, saved: true);
    final profile = await repository.getProfile();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(userId: profile.id, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Polls'), findsNothing);
    expect(find.text('Saved'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(
          key: const ValueKey('other'),
          userId: 'other-user',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('Find friends'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'text thumbnail remains tappable at large text scale dark=$dark',
      (tester) async {
        var opened = false;
        final post = CommunityPost(
          id: 'text',
          communityId: 'community',
          categoryId: 'general',
          authorId: 'author',
          text:
              '**Neighborhood update** 🌿 More news for everyone in the community.',
          status: PostStatus.published,
          createdAt: DateTime(2026),
          reactionCount: 99,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SizedBox.square(
                  dimension: 88,
                  child: ProfilePostTile(
                    post: post,
                    onTap: () => opened = true,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byIcon(WicchuIcons.heartFill), findsNothing);
        expect(find.text('99'), findsNothing);
        expect(find.textContaining('**'), findsNothing);
        await tester.tap(find.byType(ProfilePostTile));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final mode in ['personal', 'business', 'community']) {
    final publicPage = mode != 'personal';
    testWidgets('profile grid opens full post and switches to feed: $mode', (
      tester,
    ) async {
      final repository = DemoCommunityRepository();
      final community = mode == 'business'
          ? await repository.createCommunity(
              const CreateCommunityInput(
                name: 'Local business',
                description: '',
                town: Town(id: 'town-1', name: 'Town', countryCode: 'EC'),
                visibility: CommunityVisibility.public,
                categoryNames: ['General'],
                type: CommunityType.publicProfile,
                profileCategory: ProfileCategory.localBusiness,
              ),
            )
          : (await repository.listJoinedCommunities()).first;
      final category = (await repository.listCategories(community.id)).first;
      for (var i = 0; i < 3; i++) {
        await repository.createPost(
          community.id,
          CreatePostInput(categoryId: category.id, text: 'Project update $i'),
        );
      }
      final profile = await repository.getProfile();
      await tester.pumpWidget(
        MaterialApp(
          home: publicPage
              ? CommunityProfilePage(
                  community: community,
                  repository: repository,
                )
              : MemberProfilePage(userId: profile.id, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      if (mode == 'community') {
        expect(find.byType(ProfileViewSwitch), findsNothing);
        expect(find.byType(ProfilePostTile), findsNothing);
        expect(find.byType(PostCard), findsWidgets);
        expect(find.text('Newest'), findsOneWidget);
        await tester.ensureVisible(find.text('Newest'));
        await tester.tap(find.text('Newest'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Oldest').last);
        await tester.pumpAndSettle();
        expect(find.text('Oldest'), findsOneWidget);
        expect(find.byType(ProfilePostTile), findsNothing);
        expect(tester.takeException(), isNull);
        return;
      }
      if (mode == 'business') {
        expect(find.byType(PostCard), findsWidgets);
        final gridSwitch = find.byTooltip('Grid');
        await tester.ensureVisible(gridSwitch);
        await tester.tap(gridSwitch);
        await tester.pumpAndSettle();
      }
      final tiles = tester
          .widgetList<ProfilePostTile>(find.byType(ProfilePostTile))
          .toList();
      final firstSize = tester.getSize(find.byType(ProfilePostTile).first);
      expect(firstSize.width, closeTo(firstSize.height, .01));
      expect(profilePostGridDelegate.crossAxisCount, 3);
      expect(profilePostGridDelegate.crossAxisSpacing, 4);
      final previousId = tiles[0].post.id;
      final selectedId = tiles[1].post.id;
      final nextId = tiles[2].post.id;
      final tile = find.byType(ProfilePostTile).at(1);
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsNothing);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(PostCollectionPage), findsOneWidget);
      expect(find.byKey(ValueKey(selectedId)).hitTestable(), findsOneWidget);
      expect(find.byKey(ValueKey(previousId)).hitTestable(), findsNothing);
      final scroll = find.descendant(
        of: find.byType(PostCollectionPage),
        matching: find.byType(CustomScrollView),
      );
      await tester.drag(scroll, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(previousId)).hitTestable(), findsOneWidget);
      await tester.drag(scroll, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(nextId)).hitTestable(), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final switcher = find.byTooltip('Posts');
      await tester.ensureVisible(switcher);
      await tester.pumpAndSettle();
      await tester.tap(switcher);
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsWidgets);
      expect(find.byType(ProfilePostTile), findsNothing);
      final feedCard = find.byType(PostCard).first;
      await tester.ensureVisible(feedCard);
      await tester.pumpAndSettle();
      await tester.tap(feedCard);
      await tester.pumpAndSettle();
      expect(find.byType(PostCollectionPage), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
