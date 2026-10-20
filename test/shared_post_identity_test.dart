import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class SourceRepository extends DemoCommunityRepository {
  final requests = <String>[];
  final memberRequests = <String>[];

  @override
  Future<Community> getCommunity(String id) async {
    requests.add(id);
    return Community(
      id: id,
      name: id == 'wicchu-organization' ? 'Wicchu' : 'Mantenimiento Michel S.L',
      description: '',
      town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'michel',
      createdAt: DateTime(2026),
      type: CommunityType.publicProfile,
      profileCategory: id == 'wicchu-organization'
          ? ProfileCategory.organization
          : ProfileCategory.localBusiness,
    );
  }

  @override
  Future<PublicMemberProfile> getMemberProfile(String userId) async {
    memberRequests.add(userId);
    return PublicMemberProfile(
      id: userId,
      name: userId == 'wicchu-user' ? 'Wicchu account' : 'Michel',
      userName: userId == 'wicchu-user' ? 'wicchu' : 'michel',
      postCount: 1,
      communityCount: 1,
    );
  }
}

void main() {
  for (final anonymous in [false, true]) {
    testWidgets('shared identity and navigation, anonymous=$anonymous', (
      tester,
    ) async {
      final repository = SourceRepository();
      var authorTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCard(
              repository: repository,
              post: CommunityPost(
                id: 'original-post',
                communityId: 'target',
                categoryId: 'business',
                authorId: 'michel',
                text: 'Shared content',
                status: PostStatus.published,
                createdAt: DateTime(2026),
                sourceCommunityId: 'source-business',
                isCommunityShare: true,
                isAnonymous: anonymous,
              ),
              category: 'Negocios locales',
              icon: '',
              community: 'Echeandia',
              author: 'Michel',
              time: '6 days',
              text: 'Shared content',
              showActions: false,
              showCommunity: false,
              onAuthorTap: () => authorTaps++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (anonymous) {
        expect(repository.requests, isEmpty);
        expect(repository.memberRequests, isEmpty);
        expect(find.text('Anonymous Member'), findsOneWidget);
        expect(find.text('Michel'), findsNothing);
        expect(find.text('Mantenimiento Michel S.L'), findsNothing);
      } else {
        expect(repository.requests, ['source-business']);
        expect(repository.memberRequests, ['michel']);
        expect(find.text('Mantenimiento Michel S.L'), findsOneWidget);
        expect(find.text('Local business · 6 days'), findsOneWidget);
        expect(find.text(' · Negocios locales'), findsOneWidget);
        expect(find.text('Shared by @michel'), findsOneWidget);
        await tester.tap(find.text('Shared by @michel'));
        expect(authorTaps, 1);
        await tester.tap(find.text('Mantenimiento Michel S.L'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester
              .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
              .community
              .id,
          'source-business',
        );
        expect(authorTaps, 1);
      }
    });
  }

  testWidgets('organization posts use the page as primary identity', (
    tester,
  ) async {
    final repository = SourceRepository();
    var authorTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            repository: repository,
            post: CommunityPost(
              id: 'organization-post',
              communityId: 'wicchu-organization',
              categoryId: 'updates',
              authorId: 'wicchu-user',
              authorName: 'Wicchu account',
              text: 'Wicchu keeps improving',
              status: PostStatus.published,
              createdAt: DateTime(2026),
            ),
            category: 'General',
            icon: '',
            community: 'Wicchu',
            author: 'Wicchu account',
            time: '9 h',
            text: 'Wicchu keeps improving',
            showActions: false,
            onAuthorTap: () => authorTaps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wicchu'), findsOneWidget);
    expect(find.text('Organization · 9 h'), findsOneWidget);
    expect(find.text('Published by @wicchu'), findsOneWidget);
    await tester.tap(find.text('Published by @wicchu'));
    expect(authorTaps, 1);

    await tester.tap(find.text('Wicchu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
          .community
          .id,
      'wicchu-organization',
    );
  });
}
