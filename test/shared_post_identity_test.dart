import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class SourceRepository extends DemoCommunityRepository {
  final requests = <String>[];
  @override
  Future<Community> getCommunity(String id) async {
    requests.add(id);
    return Community(
      id: id,
      name: 'Mantenimiento Michel S.L',
      description: '',
      town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'michel',
      createdAt: DateTime(2026),
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
        expect(find.text('Anonymous Member'), findsOneWidget);
        expect(find.text('Michel'), findsNothing);
        expect(find.text('Mantenimiento Michel S.L'), findsNothing);
      } else {
        expect(repository.requests, ['source-business']);
        expect(find.text('Mantenimiento Michel S.L'), findsOneWidget);
        await tester.tap(find.text('Michel'));
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
}
