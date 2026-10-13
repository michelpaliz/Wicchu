import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/post_markdown.dart';
import 'package:wicchu/features/community/post_media_gallery.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 768.0]) {
      for (final kind in [
        'text',
        'image',
        'carousel',
        'poll',
        'business',
        'video',
      ]) {
        testWidgets('$kind post is borderless and ordered at $width dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final media = switch (kind) {
            'image' => const [
              PostMedia(url: 'https://example.com/photo.jpg', type: 'image'),
            ],
            'carousel' => const [
              PostMedia(url: 'https://example.com/one.jpg', type: 'image'),
              PostMedia(url: 'https://example.com/two.jpg', type: 'image'),
            ],
            'video' => const [
              PostMedia(url: 'https://example.com/video.mp4', type: 'video'),
            ],
            _ => const <PostMedia>[],
          };
          const poll = PostPoll(
            options: [
              PollOption(id: 'a', text: 'Yes', voteCount: 0),
              PollOption(id: 'b', text: 'No', voteCount: 0),
            ],
          );
          var saved = false;
          var likes = 0;
          final post = CommunityPost(
            id: 'post',
            communityId: 'community',
            categoryId: 'news',
            authorId: 'author',
            text: 'Caption',
            status: PostStatus.published,
            createdAt: DateTime(2026),
            businessFeature: kind == 'business'
                ? const BusinessPostFeature(
                    type: BusinessPostFeatureType.professionalService,
                    title: 'Repairs',
                    serviceArea: 'Town',
                  )
                : null,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? WicchuTheme.dark : WicchuTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PostCard(
                    post: post,
                    category: 'News',
                    icon: '📰',
                    community: 'Town',
                    author:
                        'A very long author name that still fits the layout safely',
                    time: 'Now',
                    text: 'Caption',
                    media: media,
                    poll: kind == 'poll' ? poll : null,
                    onPollVote: (id) async =>
                        PostPoll(options: poll.options, selectedOptionId: id),
                    onReaction: (value) async => likes = value ? 1 : 0,
                    onSaved: (value) async {
                      saved = value;
                    },
                    onComments: () async => 2,
                    onShare: () async {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Card), findsNothing);
          if (media.isNotEmpty) {
            final gallery = find.byType(PostMediaGallery);
            final caption = find.byType(PostMarkdown);
            expect(
              tester.getTopLeft(gallery).dy,
              lessThan(tester.getTopLeft(find.byTooltip('Like')).dy),
            );
            expect(
              tester.getTopLeft(find.byTooltip('Like')).dy,
              lessThan(tester.getTopLeft(caption).dy),
            );
            expect(tester.getSize(gallery).height, lessThanOrEqualTo(520));
          } else if (kind == 'poll') {
            expect(
              tester.getTopLeft(find.text('Yes')).dy,
              lessThan(tester.getTopLeft(find.byTooltip('Like')).dy),
            );
            await tester.tap(find.text('Yes'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
                  .groupValue,
              'a',
            );
          } else if (kind == 'text') {
            expect(find.byType(PostMediaGallery), findsNothing);
            expect(
              tester.getTopLeft(find.byType(PostMarkdown)).dy,
              lessThan(tester.getTopLeft(find.byTooltip('Like')).dy),
            );
          }
          await tester.ensureVisible(find.byTooltip('Like'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Like'));
          await tester.pumpAndSettle();
          expect(likes, 1);
          await tester.tap(find.byTooltip('Save'));
          await tester.pumpAndSettle();
          expect(saved, isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
