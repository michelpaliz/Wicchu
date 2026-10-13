import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/services/post_image_preparation.dart';

Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0x8088ccaa),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses image contents despite a misleading downloaded filename',
    () async {
      final result = await preparePostImage(await png(40, 20), 'download.webp');
      expect(result.filename, 'download.png');
      expect(result.mimeType, 'image/png');
      expect(result.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(result.bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 40);
      expect(frame.image.height, 20);
      final pixels = await frame.image.toByteData();
      expect(pixels!.getUint8(3), lessThan(255));
      frame.image.dispose();
      codec.dispose();
    },
  );

  test('large portrait images are bounded without stretching', () async {
    final result = await preparePostImage(await png(1200, 3000), 'photo.png');
    final codec = await ui.instantiateImageCodec(result.bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 819);
    expect(frame.image.height, 2048);
    frame.image.dispose();
    codec.dispose();
  });

  test('WebP downloads are converted to correctly labelled PNG', () async {
    final bytes = await File(
      'test/fixtures/image_picker/webpImage.webp',
    ).readAsBytes();
    final result = await preparePostImage(bytes, 'download.webp');
    expect(result.mimeType, 'image/png');
    expect(result.filename, 'download.png');
    expect(result.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('invalid image contents fail before upload', () async {
    await expectLater(
      preparePostImage(Uint8List.fromList([1, 2, 3]), 'photo.jpg'),
      throwsA(anything),
    );
  });
}
