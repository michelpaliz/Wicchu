import 'package:cross_file/cross_file.dart';

class MediaExportItem {
  const MediaExportItem({required this.url, required this.type});

  final String url;
  final String type;
}

class PreparedShareMedia {
  const PreparedShareMedia({
    required this.files,
    required this.fileNames,
    required this.cleanup,
  });

  final List<XFile> files;
  final List<String> fileNames;
  final Future<void> Function() cleanup;
}
