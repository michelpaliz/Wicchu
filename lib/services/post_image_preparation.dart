import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class PreparedPostImage {
  const PreparedPostImage(this.bytes, this.filename, this.mimeType);
  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

/// Decode the contents rather than trusting picker filenames or MIME metadata.
/// PNG keeps transparency and is accepted by the existing media upload API.
Future<PreparedPostImage> preparePostImage(
  Uint8List bytes,
  String filename,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = math.min(
      1.0,
      2048 / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    // Preserve animated GIFs instead of silently flattening them.
    final gif =
        bytes.length >= 6 &&
        String.fromCharCodes(bytes.take(6)).startsWith('GIF8');
    final base = filename.replaceFirst(RegExp(r'\.[^.]*$'), '');
    if (gif && codec.frameCount > 1) {
      return PreparedPostImage(bytes, '$base.gif', 'image/gif');
    }
    image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const FormatException('Image encoding failed');
    return PreparedPostImage(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      '${base.isEmpty ? 'photo' : base}.png',
      'image/png',
    );
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
