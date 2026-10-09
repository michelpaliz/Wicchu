import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/category_page.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';

class _Repository extends DemoCommunityRepository {
  int reads = 0;
  bool fail = false;
  @override
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  }) async {
    reads++;
    return [];
  }

  @override
  Future<void> blockUser(String userId) async {
    if (fail) throw Exception('Block failed');
    await super.blockUser(userId);
  }
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'block refreshes stacked category only on success: fail=$fail',
      (tester) async {
        final repository = _Repository()..fail = fail;
        final community = (await repository.listJoinedCommunities()).first;
        final category = (await repository.listCategories(community.id)).first;
        await tester.pumpWidget(
          MaterialApp(
            home: CategoryPage(
              community: community,
              category: category,
              canPost: true,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = repository.reads;
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                MemberProfilePage(userId: 'other-user', repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Message'), findsOneWidget);
        expect(find.byTooltip('Share profile'), findsOneWidget);
        expect(find.text('Block user'), findsNothing);
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        expect(find.text('Report profile'), findsOneWidget);
        await tester.tap(find.text('Block user'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Block'));
        await tester.pumpAndSettle();
        expect(repository.reads, fail ? before : before + 1);
        expect(
          find.byType(MemberProfilePage),
          fail ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
