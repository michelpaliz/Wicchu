import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/widgets/feed_filter_bar.dart';

class _PreviewRepository extends DemoCommunityRepository {
  int postReads = 0;
  @override
  Future<List<CommunityPost>> listPosts(
    String id, {
    String? categoryId,
    String? query,
    String? sort,
  }) async {
    postReads++;
    return [];
  }
}

void main() {
  for (final visibility in CommunityVisibility.values) {
    testWidgets('non-member preview respects $visibility', (tester) async {
      final repository = _PreviewRepository();
      final original = (await repository.listCommunities()).first;
      final community = Community(
        id: original.id,
        name: original.name,
        description: original.description,
        town: original.town,
        visibility: visibility,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
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
      expect(
        repository.postReads,
        visibility == CommunityVisibility.public ? 1 : 0,
      );
      if (visibility == CommunityVisibility.public) {
        expect(
          find.text('Community preview. Join to take part.'),
          findsOneWidget,
        );
      } else {
        expect(find.text('Join to view community posts.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('membership options open in a bottom sheet', (tester) async {
    final repository = DemoCommunityRepository();
    final original = (await repository.listJoinedCommunities()).first;
    final community = Community(
      id: original.id,
      name: original.name,
      shortDescription: original.shortDescription,
      description: original.description,
      town: original.town,
      visibility: original.visibility,
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      myRole: CommunityRole.member,
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
    await tester.tap(find.byKey(const ValueKey('community-role-badge')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('You are a member of this community'), findsOneWidget);
    expect(find.text('Leave community'), findsOneWidget);
  });

  testWidgets(
    'description starts expanded, can collapse, and administration opens filtered members',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = DemoCommunityRepository();
      final original = (await repository.listJoinedCommunities()).first;
      final community = Community(
        id: original.id,
        name: original.name,
        shortDescription: List.filled(
          3,
          'A concise summary of local news and events.',
        ).join(' '),
        description: List.filled(
          10,
          'News, events and stories from our local community.',
        ).join(' '),
        town: original.town,
        visibility: original.visibility,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
        myRole: CommunityRole.member,
        memberCount: original.memberCount,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: repository,
            screen: CommunityScreen.information,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(community.description)).maxLines,
        isNull,
      );
      expect(
        tester.widget<Text>(find.text(community.shortDescription)).maxLines,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.tap(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('community-information-content')),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(community.shortDescription)).maxLines,
        2,
      );
      expect(
        tester.widget<Text>(find.text(community.description)).maxLines,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.tap(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('community-information-content')),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(community.shortDescription)).maxLines,
        isNull,
      );
      final admins = find.byKey(
        const ValueKey('information-administration-entry'),
      );
      await tester.scrollUntilVisible(
        admins,
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('community-information-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(admins), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(admins);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FeedFilterBar>(find.byType(FeedFilterBar)).selectedIndex,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
