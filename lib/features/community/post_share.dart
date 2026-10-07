import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/wicchu_urls.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'post_media_export.dart';

enum PostShareDestination {
  instagramStory,
  instagramFeed,
  whatsapp,
  facebook,
  system,
  copyLink,
}

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

Future<void> _shareGeneratedImage(
  BuildContext context,
  PostShareKit kit,
  String imageUrl, {
  required String title,
}) async {
  final shareOrigin = _shareOrigin(context);
  final copiedMessage = context.tr(
    'Caption copied. Paste it in Instagram if needed.',
  );
  await Clipboard.setData(ClipboardData(text: kit.message));
  final prepared = await preparePostMedia([
    MediaExportItem(url: imageUrl, type: 'image'),
  ]);
  try {
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        title: title,
        text: kit.message,
        files: prepared.files,
        fileNameOverrides: prepared.fileNames,
        sharePositionOrigin: shareOrigin,
      ),
    );
  } finally {
    await prepared.cleanup();
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copiedMessage)));
  }
}

Future<void> _openSocialUrl(
  BuildContext context,
  String value,
  String fallbackMessage,
) async {
  final shareOrigin = _shareOrigin(context);
  final uri = Uri.tryParse(value);
  if (uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    return;
  }
  await SharePlus.instance.share(
    ShareParams(text: fallbackMessage, sharePositionOrigin: shareOrigin),
  );
}

Future<void> sharePostTo(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post,
  PostShareDestination destination,
) async {
  var progressOpen = false;
  try {
    if (destination != PostShareDestination.copyLink) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(context.tr('Preparing share…'))),
            ],
          ),
        ),
      );
      progressOpen = true;
    }
    final kit = await repository.getPostShareKit(post.id);
    await repository.recordPostShare(post.id).catchError((_) {});
    if (!context.mounted) return;
    if (progressOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      progressOpen = false;
    }
    switch (destination) {
      case PostShareDestination.instagramStory:
        await _shareGeneratedImage(
          context,
          kit,
          kit.instagramStoryImageUrl,
          title: context.tr('Instagram Story'),
        );
      case PostShareDestination.instagramFeed:
        await _shareGeneratedImage(
          context,
          kit,
          kit.instagramFeedImageUrl,
          title: context.tr('Instagram Post'),
        );
      case PostShareDestination.whatsapp:
        await _openSocialUrl(context, kit.whatsappUrl, kit.message);
      case PostShareDestination.facebook:
        await _openSocialUrl(context, kit.facebookUrl, kit.message);
      case PostShareDestination.system:
        await SharePlus.instance.share(
          ShareParams(
            subject: 'Wicchu',
            text: kit.message,
            sharePositionOrigin: _shareOrigin(context),
          ),
        );
      case PostShareDestination.copyLink:
        await Clipboard.setData(ClipboardData(text: kit.canonicalUrl));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.tr('Link copied'))));
        }
    }
  } catch (error) {
    if (context.mounted) {
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }
}

Future<void> sharePost(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post, {
  String? communityName,
}) async {
  final destination = await showModalBottomSheet<PostShareDestination>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(sheetContext.tr('Instagram Story')),
              subtitle: Text(
                sheetContext.tr('Share a Wicchu-designed 9:16 image.'),
              ),
              onTap: () => Navigator.pop(
                sheetContext,
                PostShareDestination.instagramStory,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(sheetContext.tr('Instagram Post')),
              subtitle: Text(
                sheetContext.tr('Share a Wicchu-designed 4:5 image.'),
              ),
              onTap: () => Navigator.pop(
                sheetContext,
                PostShareDestination.instagramFeed,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.whatsapp),
            ),
            ListTile(
              leading: const Icon(Icons.facebook_outlined),
              title: const Text('Facebook'),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.facebook),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: Text(sheetContext.tr('More sharing options')),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.system),
            ),
            ListTile(
              leading: const Icon(Icons.link_outlined),
              title: Text(sheetContext.tr('Copy link')),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.copyLink),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (destination == null || !context.mounted) return;
  await sharePostTo(context, repository, post, destination);
}
