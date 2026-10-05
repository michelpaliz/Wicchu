import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/comments_sheet.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_media_gallery.dart';

void main() {
  testWidgets(
    'post viewer scrolls to comments, retains immersive state and syncs reactions',
    (tester) async {
      final repository = DemoCommunityRepository();
      final community = (await repository.listJoinedCommunities()).first;
      final category = (await repository.listCategories(community.id)).first;
      final post = await repository.createPost(
        community.id,
        CreatePostInput(
          categoryId: category.id,
          text: 'A shared caption',
          media: const [
            PostMedia(url: 'https://example.com/one.jpg', type: 'image'),
            PostMedia(url: 'https://example.com/two.jpg', type: 'image'),
          ],
        ),
      );
      await repository.createComment(post.id, 'An existing comment');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCard(
                repository: repository,
                post: post,
                category: category.name,
                icon: category.icon,
                community: community.name,
                author: post.authorName,
                time: 'Now',
                text: post.text,
                media: post.media,
                onReaction: (liked) =>
                    repository.setPostReaction(post.id, reacted: liked),
                onComments: () async => 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-post-media-1')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.byType(PostComments), findsOneWidget);
      final page = find.byType(PageView);
      await tester.tapAt(tester.getTopLeft(page) + const Offset(40, 120));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.text('A shared caption'), findsNothing);
      await tester.tapAt(tester.getTopLeft(page) + const Offset(40, 120));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Like').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Like').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unlike'), findsOneWidget);
      await tester.ensureVisible(find.text('An existing comment'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(page).dy, lessThan(0));
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'A new comment');
      await tester.pump();
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect((await repository.listComments(post.id)).length, 2);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PostMediaViewer), findsNothing);
      expect(find.byTooltip('Unlike'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('previews open the selected image and browse all attachments', (
    tester,
  ) async {
    const media = [
      PostMedia(url: 'https://example.com/one.jpg', type: 'image'),
      PostMedia(url: 'https://example.com/two.jpg', type: 'image'),
      PostMedia(url: 'https://example.com/three.jpg', type: 'image'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PostMediaGallery(media: media)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-post-media-1')));
    await tester.pumpAndSettle();
    expect(find.byType(PostMediaViewer), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next media'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous media'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    final viewer = find.byType(InteractiveViewer).hitTestable().first;
    final point = tester.getCenter(viewer);
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      2.5,
    );
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(PostMediaViewer), findsNothing);
    expect(find.byType(PostMediaGallery), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
