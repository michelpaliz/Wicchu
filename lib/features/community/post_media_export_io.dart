import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

import 'post_media_export_types.dart';

String _extension(MediaExportItem item, String? contentType) {
  final path = Uri.tryParse(item.url)?.path.toLowerCase() ?? '';
  for (final extension in ['.jpg', '.jpeg', '.png', '.webp', '.mp4', '.mov']) {
    if (path.endsWith(extension)) return extension;
  }
  if (contentType?.contains('png') == true) return '.png';
  if (contentType?.contains('webp') == true) return '.webp';
  if (contentType?.contains('quicktime') == true) return '.mov';
  if (item.type == 'video') return '.mp4';
  return '.jpg';
}

Future<PreparedShareMedia> preparePostMedia(
  List<MediaExportItem> items, {
  http.Client? client,
}) async {
  final directory = await Directory.systemTemp.createTemp('wicchu-share-');
  final ownsClient = client == null;
  final activeClient = client ?? http.Client();
  final files = <XFile>[];
  final names = <String>[];
  try {
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final response = await activeClient.send(
        http.Request('GET', Uri.parse(item.url)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Unable to prepare post media (${response.statusCode})',
        );
      }
      final contentType = response.headers['content-type'];
      final name = 'wicchu-${index + 1}${_extension(item, contentType)}';
      final file = File('${directory.path}/$name');
      final sink = file.openWrite();
      try {
        await response.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      names.add(name);
      files.add(XFile(file.path, mimeType: contentType));
    }
    return PreparedShareMedia(
      files: files,
      fileNames: names,
      cleanup: () async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      },
    );
  } catch (_) {
    if (await directory.exists()) await directory.delete(recursive: true);
    rethrow;
  } finally {
    if (ownsClient) activeClient.close();
  }
}
