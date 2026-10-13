import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/comments_sheet.dart';

class _Repository extends DemoCommunityRepository {
  _Repository(this.community);
  final Community community;
  List<CommunityPost> posts = [];
  int reads = 0;
  int requests = 0;
  int comments = 0;
  @override
  Future<Community> getCommunity(String id) async => community;
  @override
  Future<void> joinCommunity(String id) async {
    requests++;
  }

  @override
  Future<List<CommunityPost>> listPosts(
    String id, {
    String? categoryId,
    String? query,
    String? sort,
  }) async {
    reads++;
    return posts;
  }

  @override
  Future<List<Comment>> listComments(String id) async => [];
  @override
  Future<Comment> createComment(
    String id,
    String text, {
    String? parentCommentId,
  }) async {
    comments++;
    return super.createComment(id, text, parentCommentId: parentCommentId);
  }
}

Community page({
  bool private = false,
  bool business = false,
  ProfileCategory? category,
}) => Community(
  id: 'preview',
  name: 'Preview page',
  description: 'Description',
  town: const Town(id: 'town', name: 'Town', countryCode: 'ES'),
  visibility: private
      ? CommunityVisibility.private
      : CommunityVisibility.public,
  createdBy: 'owner',
  createdAt: DateTime(2026),
  type: business || category != null
      ? CommunityType.publicProfile
      : CommunityType.community,
  profileCategory:
      category ?? (business ? ProfileCategory.localBusiness : null),
);

void main() {
  for (final category in <ProfileCategory?>[null, ...ProfileCategory.values]) {
    testWidgets(
      'nonmember sees published feed for ${category?.name ?? 'community'}',
      (tester) async {
        final repository = _Repository(page(category: category))
          ..posts = [
            CommunityPost(
              id: 'public-post',
              communityId: 'preview',
              categoryId: 'news',
              authorId: 'author',
              text: 'Visible public publication',
              status: PostStatus.published,
              createdAt: DateTime(2026),
            ),
          ];
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              community: repository.community,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.community.isJoined, isFalse);
        expect(repository.reads, greaterThan(0));
        expect(
          find.text('Visible public publication', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Join to view community posts.'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'public business content is available without following or a banner',
    (tester) async {
      final repository = _Repository(page(business: true));
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: repository.community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.reads, greaterThan(0));
      expect(
        find.text('Page preview. Follow to stay connected.'),
        findsNothing,
      );
      expect(find.byTooltip('Follow'), findsWidgets);
    },
  );

  testWidgets('pending private join does not grant access to posts', (
    tester,
  ) async {
    final repository = _Repository(page(private: true));
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: repository.community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('header-follow-action')));
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    expect(repository.reads, 0);
    expect(find.text('Request sent'), findsOneWidget);
    expect(find.text('Join to view community posts.'), findsOneWidget);
  });

  testWidgets('nonmember can read comments but must join to submit', (
    tester,
  ) async {
    final repository = _Repository(page());
    final post = CommunityPost(
      id: 'post',
      communityId: 'preview',
      categoryId: 'news',
      authorId: 'author',
      text: 'News',
      status: PostStatus.published,
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostComments(
            repository: repository,
            post: post,
            onCountChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();
    expect(repository.comments, 0);
    expect(find.text('Join this community to comment.'), findsOneWidget);
  });
}
