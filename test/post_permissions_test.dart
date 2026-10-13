import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'package:wicchu/features/community/post_rich_text_editor.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/post_share.dart';

class _WizardRepository extends DemoCommunityRepository {
  _WizardRepository(this.community);

  Community community;
  PostStatus resultStatus = PostStatus.published;
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
      status: resultStatus,
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

Future<void> _openPreview(
  WidgetTester tester,
  _WizardRepository repository,
) async {
  final category = CommunityCategory(
    id: 'general',
    communityId: 'space',
    name: 'General',
    icon: '💬',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: CreatePostPage(
        community: repository.community,
        repository: repository,
        initialCategory: category,
        categories: [category],
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('next-post-step')));
  await tester.pumpAndSettle();
  tester
      .widget<PostRichTextEditor>(find.byType(PostRichTextEditor))
      .controller
      .replaceText(
        0,
        0,
        'Test publication',
        const TextSelection.collapsed(offset: 16),
      );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('next-post-step')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('next-post-step')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'new draft clears important announcement and preview is read only',
    (tester) async {
      final repository = _WizardRepository(
        space(CommunityType.community, CommunityRole.owner),
      );
      await _openPreview(tester, repository);
      final preview = tester.widget<PostCard>(find.byType(PostCard));
      expect(preview.showActions, isFalse);
      expect(preview.showMenu, isFalse);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Important announcement',
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next-post-step')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('publish-post')));
      await tester.pumpAndSettle();
      expect(repository.createdInput!.importantAnnouncement, isTrue);
      await tester.ensureVisible(find.text('Create another post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create another post'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next-post-step')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<PostRichTextEditor>(find.byType(PostRichTextEditor))
          .controller;
      expect(controller.text, isEmpty);
      controller.replaceText(
        0,
        0,
        'Second post',
        const TextSelection.collapsed(offset: 11),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('next-post-step')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    },
  );

  testWidgets('permission change releases publish state and allows retry', (
    tester,
  ) async {
    final allowed = space(
      CommunityType.publicProfile,
      CommunityRole.owner,
      ProfileCategory.localBusiness,
    );
    final repository = _WizardRepository(allowed);
    await _openPreview(tester, repository);
    repository.community = space(
      CommunityType.publicProfile,
      CommunityRole.member,
      ProfileCategory.localBusiness,
    );
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();
    expect(repository.createdInput, isNull);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('publish-post')))
          .onPressed,
      isNotNull,
    );
    repository.community = allowed;
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();
    expect(find.text('Post published'), findsOneWidget);
  });

  testWidgets('pending posts cannot be shared from the success screen', (
    tester,
  ) async {
    final repository = _WizardRepository(
      space(CommunityType.community, CommunityRole.member),
    )..resultStatus = PostStatus.pendingApproval;
    await _openPreview(tester, repository);
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();
    expect(find.text('Post submitted for approval'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('View post'), findsNothing);
    expect(find.byKey(const ValueKey('share-published-post')), findsNothing);
  });

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

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
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
    controller.formatText(0, 19, quill.Attribute.bold);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    expect(find.text('Post options'), findsOneWidget);
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('General').last);
    await tester.pumpAndSettle();
    expect(find.text('Post options'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsOneWidget);
    expect(
      tester.widget<PostCard>(find.byType(PostCard)).text,
      '**Neighborhood update**',
    );
    expect(find.text('Copy description'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();

    expect(repository.createdInput?.text, '**Neighborhood update**');
    expect(find.text('Post published'), findsOneWidget);
    expect(find.text('View post'), findsOneWidget);
    expect(find.text('Create another post'), findsOneWidget);
    expect(find.text('Copy description'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('share-published-post')),
    );
    await tester.tap(find.byKey(const ValueKey('share-published-post')));
    await tester.pumpAndSettle();
    expect(find.byType(WicchuShareSheet), findsOneWidget);
    expect(find.text('Instagram Story'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Post published'), findsOneWidget);
  });

  testWidgets('anonymous poll preview uses the feed card without publishing', (
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
          categories: [category],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('post-kind-poll')));
    await tester.tap(find.byKey(const ValueKey('post-kind-poll')));
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PostRichTextEditor>(find.byType(PostRichTextEditor))
        .controller;
    controller.replaceText(
      0,
      0,
      'Where shall we meet?',
      const TextSelection.collapsed(offset: 19),
    );
    final options = find.byType(TextField);
    await tester.enterText(options.at(0), 'Town hall');
    await tester.enterText(options.at(1), 'Park');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.tap(find.byTooltip('About anonymous posts'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Anonymous posts are always reviewed by a community administrator before publication. Administrators can still identify you for safety.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    final preview = tester.widget<PostCard>(find.byType(PostCard));
    expect(preview.author, 'Anonymous Member');
    expect(preview.authorAvatarUrl, isNull);
    expect(preview.isAnonymousAuthor, isTrue);
    expect(preview.poll!.options.map((option) => option.text), [
      'Town hall',
      'Park',
    ]);
    expect(preview.poll!.totalVotes, 0);
    expect(preview.onPollVote, isNull);
    expect(repository.createdInput, isNull);
    expect(tester.takeException(), isNull);
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
