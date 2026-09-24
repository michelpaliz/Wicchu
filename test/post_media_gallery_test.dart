import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_media_gallery.dart';

void main() {
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
