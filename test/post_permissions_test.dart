import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'package:wicchu/features/community/post_rich_text_editor.dart';

class _WizardRepository extends DemoCommunityRepository {
  _WizardRepository(this.community);

  final Community community;
  CreatePostInput? createdInput;

  @override
  Future<Community> getCommunity(String communityId) async => community;

  @override
  Future<CommunityPost> createPost(
    String communityId,
    CreatePostInput input,
  ) async {
    createdInput = input;
    return CommunityPost(
      id: 'new-post',
      communityId: communityId,
      categoryId: input.categoryId,
      authorId: 'current-user',
      text: input.text,
      status: PostStatus.published,
      createdAt: DateTime.utc(2026, 10, 6),
    );
  }
}

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
  testWidgets('new post uses four steps and finishes on a success screen', (
    tester,
  ) async {
    final community = space(CommunityType.community, CommunityRole.member);
    final repository = _WizardRepository(community);
    final category = CommunityCategory(
      id: 'general',
      communityId: community.id,
      name: 'General',
      icon: '💬',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          community: community,
          repository: repository,
          initialCategory: category,
          categories: [category],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Type'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PostRichTextEditor>(find.byType(PostRichTextEditor))
        .controller;
    controller.replaceText(
      0,
      0,
      'Neighborhood update',
      const TextSelection.collapsed(offset: 19),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    expect(find.text('Post options'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    expect(find.text('Neighborhood update'), findsOneWidget);
    expect(find.text('Copy description'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();

    expect(repository.createdInput?.text, 'Neighborhood update');
    expect(find.text('Post published'), findsOneWidget);
    expect(find.text('View post'), findsOneWidget);
    expect(find.text('Create another post'), findsOneWidget);
    expect(find.text('Copy description'), findsOneWidget);
  });

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
