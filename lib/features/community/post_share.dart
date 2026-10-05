import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/wicchu_urls.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'post_media_export.dart';

String socialPostCaption(CommunityPost post) {
  final caption = post.text.trim();
  final link = WicchuUrls.post(post.id);
  return caption.isEmpty ? link : '$caption\n\n$link';
}

Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _shareLink(
  BuildContext context,
  CommunityPost post,
  String? communityName,
) async {
  final excerpt = post.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final shortened = excerpt.length > 160
      ? '${excerpt.substring(0, 157)}…'
      : excerpt;
  await SharePlus.instance.share(
    ShareParams(
      subject: communityName == null
          ? 'A post on Wicchu'
          : '$communityName on Wicchu',
      text:
          '$shortened\n\nRead the full post on Wicchu:\n'
          '${WicchuUrls.post(post.id)}',
      sharePositionOrigin: _shareOrigin(context),
    ),
  );
}

Future<void> _shareMedia(BuildContext context, CommunityPost post) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(context.tr('Preparing media…'))),
        ],
      ),
    ),
  );
  PreparedShareMedia? prepared;
  var progressOpen = true;
  try {
    prepared = await preparePostMedia([
      for (final media in post.media)
        MediaExportItem(url: media.url, type: media.type),
    ]);
    await Clipboard.setData(ClipboardData(text: socialPostCaption(post)));
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      progressOpen = false;
    }
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        title: context.tr('Create an Instagram or Facebook post'),
        files: prepared.files,
        fileNameOverrides: prepared.fileNames,
        sharePositionOrigin: _shareOrigin(context),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Caption copied. In Instagram, choose Feed and paste the caption.',
            ),
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  } finally {
    await prepared?.cleanup();
  }
}

Future<void> sharePost(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post, {
  String? communityName,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.media.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                sheetContext.tr('Create an Instagram or Facebook post'),
              ),
              subtitle: Text(
                sheetContext.tr(
                  'Exports only the original media so the social app can open its post composer.',
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, 'media'),
            ),
          ListTile(
            leading: const Icon(Icons.link_outlined),
            title: Text(sheetContext.tr('Share Wicchu link')),
            onTap: () => Navigator.pop(sheetContext, 'link'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  await repository.recordPostShare(post.id).catchError((_) {});
  if (!context.mounted) return;
  if (action == 'media') {
    await _shareMedia(context, post);
  } else {
    await _shareLink(context, post, communityName);
  }
}
