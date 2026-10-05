import 'package:http/http.dart' as http;

import 'post_media_export_types.dart';

Future<PreparedShareMedia> preparePostMedia(
  List<MediaExportItem> items, {
  http.Client? client,
}) => throw UnsupportedError('Media sharing is not supported on this device.');
