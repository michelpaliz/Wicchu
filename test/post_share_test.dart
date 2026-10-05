import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_share.dart';
import 'package:wicchu/features/community/post_media_export.dart';

CommunityPost _post({List<PostMedia> media = const []}) => CommunityPost(
  id: 'post-1',
  communityId: 'community-1',
  categoryId: 'general',
  authorId: 'user-1',
  text: 'Original caption',
  status: PostStatus.published,
  createdAt: DateTime.utc(2026, 10, 5),
  media: media,
);

void main() {
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

  testWidgets('media posts offer social export and link sharing', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final post = _post(
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

    expect(find.text('Create an Instagram or Facebook post'), findsOneWidget);
    expect(
      find.text(
        'Exports only the original media so the social app can open its post composer.',
      ),
      findsOneWidget,
    );
    expect(find.text('Share Wicchu link'), findsOneWidget);
  });
}
