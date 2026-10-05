import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;

import 'post_media_export_types.dart';

Future<PreparedShareMedia> preparePostMedia(
  List<MediaExportItem> items, {
  http.Client? client,
}) async {
  final ownsClient = client == null;
  final activeClient = client ?? http.Client();
  final files = <XFile>[];
  final names = <String>[];
  try {
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final response = await activeClient.get(Uri.parse(item.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Unable to prepare post media');
      }
      final contentType = response.headers['content-type'];
      final extension = item.type == 'video' ? 'mp4' : 'jpg';
      final name = 'wicchu-${index + 1}.$extension';
      names.add(name);
      files.add(
        XFile.fromData(response.bodyBytes, mimeType: contentType, name: name),
      );
    }
    return PreparedShareMedia(
      files: files,
      fileNames: names,
      cleanup: () async {},
    );
  } finally {
    if (ownsClient) activeClient.close();
  }
}
