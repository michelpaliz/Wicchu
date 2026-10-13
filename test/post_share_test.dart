import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_share.dart';
import 'package:wicchu/features/community/post_media_export.dart';

CommunityPost _post({
  List<PostMedia> media = const [],
  String text = 'Original caption',
  bool canShareToCommunities = false,
}) => CommunityPost(
  id: 'post-1',
  communityId: 'community-1',
  categoryId: 'general',
  authorId: 'user-1',
  text: text,
  status: PostStatus.published,
  createdAt: DateTime.utc(2026, 10, 5),
  media: media,
  canShareToCommunities: canShareToCommunities,
);

class _ShareKitRepository extends DemoCommunityRepository {
  bool fail = false;
  @override
  Future<PostShareKit> getPostShareKit(String postId) async {
    if (fail) throw Exception('Share unavailable');
    return const PostShareKit(
      canonicalUrl: 'https://wicchu.com/posts/post-1',
      message: 'Caption',
      whatsappUrl: 'https://wa.me/',
      facebookUrl: 'https://facebook.com/',
      instagramFeedImageUrl: 'https://wicchu.com/feed.png',
      instagramStoryImageUrl: 'https://wicchu.com/story.png',
    );
  }
}

void main() {
  testWidgets(
    'caption is copied before sharing confirmation and supports cancel',
    (tester) async {
      String? copied;
      bool? proceed;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  proceed = await confirmCopiedShareCaption(
                    context,
                    'Caption and link',
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(copied, 'Caption and link');
      expect(proceed, isNull);
      expect(find.text('Description copied'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(proceed, isFalse);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share on Instagram'));
      await tester.pumpAndSettle();
      expect(proceed, isTrue);
    },
  );

  testWidgets(
    'copy link uses share kit and failed preparation returns to page',
    (tester) async {
      final repository = _ShareKitRepository();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => sharePostTo(
                      context,
                      repository,
                      _post(),
                      PostShareDestination.copyLink,
                    ),
                    child: const Text('Copy'),
                  ),
                  TextButton(
                    onPressed: () => sharePostTo(
                      context,
                      repository,
                      _post(),
                      PostShareDestination.instagramStory,
                    ),
                    child: const Text('Export'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, 'https://wicchu.com/posts/post-1');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      repository.fail = true;
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Share unavailable'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    },
  );

  testWidgets(
    'compact sheet scrolls with large text and respects permissions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      PostShareDestination? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2),
              ),
              child: WicchuShareSheet(
                canShareToCommunities: false,
                hasMedia: false,
                onSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Community'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Copy link'));
      await tester.tap(find.text('Copy link'));
      expect(selected, PostShareDestination.copyLink);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'copied captions remove markdown escapes and formatting but preserve URLs',
    () {
      final caption = socialPostCaption(
        _post(
          text:
              r'**Hola** \! _Vecinos_'
              '\n\nhttps://example.com/a/b 🌿',
        ),
      );
      expect(
        caption,
        startsWith('Hola ! Vecinos\n\nhttps://example.com/a/b 🌿'),
      );
      expect(caption, isNot(contains('**')));
      expect(caption, contains('/posts/post-1'));
    },
  );

  test('social export keeps the caption and Wicchu attribution link', () {
    final caption = socialPostCaption(_post());

    expect(caption, startsWith('Original caption'));
    expect(caption, contains('/posts/post-1'));
  });

  test('social export preserves multiple media files in order', () async {
    final client = MockClient((request) async {
      final isVideo = request.url.path.endsWith('.mp4');
      return http.Response.bytes(
        isVideo ? [4, 5, 6] : [1, 2, 3],
        200,
        headers: {'content-type': isVideo ? 'video/mp4' : 'image/jpeg'},
      );
    });

    final prepared = await preparePostMedia([
      const MediaExportItem(
        url: 'https://wicchu.test/first.jpg',
        type: 'image',
      ),
      const MediaExportItem(
        url: 'https://wicchu.test/second.mp4',
        type: 'video',
      ),
    ], client: client);

    expect(prepared.fileNames, ['wicchu-1.jpg', 'wicchu-2.mp4']);
    expect(await prepared.files[0].readAsBytes(), [1, 2, 3]);
    expect(await prepared.files[1].readAsBytes(), [4, 5, 6]);
    final directory = Directory(prepared.files.first.path).parent;
    await prepared.cleanup();
    expect(await directory.exists(), isFalse);
  });

  testWidgets('posts offer generated social cards and link sharing', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final post = _post(
      canShareToCommunities: true,
      media: const [
        PostMedia(url: 'https://example.com/photo.jpg', type: 'image'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => sharePost(context, repository, post),
              child: const Text('Open share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('Instagram Story'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Vertical image · 9:16'), findsOneWidget);
    expect(find.text('Instagram Post'), findsOneWidget);
    expect(
      find.text('Share the original photos or videos without cropping.'),
      findsOneWidget,
    );
    expect(find.text('Share a Wicchu-designed 4:5 image.'), findsNothing);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    await tester.ensureVisible(find.text('More sharing options'));
    await tester.tap(find.text('More sharing options'));
    await tester.pumpAndSettle();
    expect(find.text('Share original media'), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.ensureVisible(find.text('Copy description and link'));
    await tester.tap(find.text('Copy description and link'));
    await tester.pumpAndSettle();
    expect(copied, socialPostCaption(post));
    expect(find.text('Description and Wicchu link copied.'), findsOneWidget);
  });
}
