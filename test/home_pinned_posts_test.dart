import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/main/home_pinned_posts.dart';
import 'package:wicchu/features/community/post_media_gallery.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/widgets/wicchu_network_image.dart';

void main() {
  testWidgets('wide banners retain their natural feed height', (tester) async {
    const url = 'https://example.com/wide-banner.jpg';
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1200, 300),
      Paint()..color = Colors.teal,
    );
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(1200, 300)))!;
    picture.dispose();
    final provider = ResizeImage.resizeIfNeeded(
      1200,
      null,
      CachedNetworkImageProvider(url, cacheKey: stableImageCacheKey(url)),
    );
    final key = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: PostMediaGallery(
                media: [PostMedia(url: url, type: 'image')],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('post-media-carousel'))).height,
      closeTo(80, 1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('Spanish pinned carousel fits narrow screens in both themes', (
    tester,
  ) async {
    final manifest =
        await rootBundle.loadString('FontManifest.json').then(jsonDecode)
            as List<dynamic>;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final dark in [false, true]) {
      String? opened;
      final key = GlobalKey();
      final posts = [
        for (final id in ['first', 'second'])
          CommunityPost(
            id: id,
            communityId: 'community',
            categoryId: 'general',
            authorId: 'author',
            text: id == 'first'
                ? '¡Bienvenidos a la comunidad de Echeandía!'
                : 'Wicchu sigue creciendo y mejorando para todos',
            status: PostStatus.published,
            createdAt: DateTime.now(),
            pinned: true,
            media: id == 'first'
                ? const [
                    PostMedia(
                      url: 'https://example.com/pinned.jpg',
                      type: 'image',
                    ),
                  ]
                : const [],
            authorName: 'Wicchu',
          ),
      ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: HomePinnedPosts(
                posts: posts,
                communities: const {},
                onOpen: (post) => opened = post.id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Card), findsNothing);
      expect(find.text('2'), findsOneWidget);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/wicchu-pinned-${dark ? "dark" : "light"}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.drag(
        find.byKey(const ValueKey('home-pinned-carousel')),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-pinned-second')));
      expect(opened, 'second');
      expect(tester.takeException(), isNull);
    }
  });
}
