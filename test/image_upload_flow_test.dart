import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/features/community/create_post_page.dart';

class _Picker extends ImagePickerPlatform {
  _Picker(this.bytes);

  final Uint8List bytes;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    bytes,
    name: 'generated-image.webp',
    mimeType: 'image/webp',
  );
}

class _UploadRepository extends DemoCommunityRepository {
  final uploads = <({List<int> bytes, String filename, String mimeType})>[];

  @override
  Future<PostMedia> uploadPostMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    uploads.add((bytes: bytes, filename: filename, mimeType: mimeType));
    return PostMedia(
      url: 'https://example.test/$filename',
      type: 'image',
      blobName: filename,
    );
  }
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 80, 50),
    Paint()..color = const Color(0xff5bd6b1),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(80, 50);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Community _community() => Community(
  id: 'community',
  name: 'Echeandía',
  description: 'Community description',
  town: const Town(id: 'town', name: 'Echeandía', countryCode: 'EC'),
  visibility: CommunityVisibility.public,
  createdBy: 'owner',
  createdAt: DateTime.utc(2026),
  myRole: CommunityRole.owner,
);

Future<void> _pumpUntilUploaded(
  WidgetTester tester,
  _UploadRepository repository,
  int count,
) async {
  await tester.runAsync(() async {
    for (
      var attempt = 0;
      attempt < 100 && repository.uploads.length < count;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  expect(repository.uploads, hasLength(count));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ImagePickerPlatform originalPicker;
  late _UploadRepository repository;

  setUp(() async {
    originalPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _Picker(await _png());
    repository = _UploadRepository();
  });

  tearDown(() => ImagePickerPlatform.instance = originalPicker);

  testWidgets('new post image is converted and previewed from local bytes', (
    tester,
  ) async {
    final category = CommunityCategory(
      id: 'general',
      communityId: 'community',
      name: 'General',
      icon: '💬',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          community: _community(),
          repository: repository,
          initialCategory: category,
          categories: [category],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post-add-media-area')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo'));
    await _pumpUntilUploaded(tester, repository, 1);

    expect(repository.uploads.single.filename, endsWith('.png'));
    expect(repository.uploads.single.mimeType, 'image/png');
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('community cover and avatar use converted local previews', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunitySettingsPage(
          community: _community(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-community-cover')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change cover photo'));
    await _pumpUntilUploaded(tester, repository, 1);
    await tester.tap(find.byTooltip('Change community photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change photo'));
    await _pumpUntilUploaded(tester, repository, 2);

    expect(
      repository.uploads.every(
        (upload) =>
            upload.filename.endsWith('.png') && upload.mimeType == 'image/png',
      ),
      isTrue,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });
}
