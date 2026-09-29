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

void main() {
  testWidgets('saved tab is private and shows saved content', (tester) async {
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
    await tester.ensureVisible(find.text('Saved'));
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProfilePostTile>(find.byType(ProfilePostTile)).post.id,
      saved.id,
    );
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

  for (final publicPage in [false, true]) {
    testWidgets(
      'profile grid opens full post and switches to feed: public=$publicPage',
      (tester) async {
        final repository = DemoCommunityRepository();
        final community = publicPage
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
        final tiles = tester
            .widgetList<ProfilePostTile>(find.byType(ProfilePostTile))
            .toList();
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
      },
    );
  }
}
