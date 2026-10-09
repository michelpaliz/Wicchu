import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/wicchu_urls.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'post_media_export.dart';
import 'post_markdown.dart';

enum PostShareDestination {
  instagramStory,
  instagramFeed,
  whatsapp,
  facebook,
  system,
  copyLink,
  copyCaption,
  originalMedia,
}

String socialPostCaption(CommunityPost post) {
  final caption = postPlainText(post.text, preserveParagraphs: true);
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
    'Description and Wicchu link copied. Paste them into your social post.',
  );
  await Clipboard.setData(ClipboardData(text: kit.message));
  final prepared = await preparePostMedia([
    MediaExportItem(url: imageUrl, type: 'image'),
  ]);
  try {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copiedMessage)));
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Description and Wicchu link copied. Paste them into your social post.',
          ),
        ),
      ),
    );
    await SharePlus.instance.share(
      ShareParams(
        title: context.tr('Create an Instagram or Facebook post'),
        files: prepared.files,
        fileNameOverrides: prepared.fileNames,
        sharePositionOrigin: _shareOrigin(context),
      ),
    );
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
    if (destination == PostShareDestination.copyCaption) {
      await Clipboard.setData(ClipboardData(text: socialPostCaption(post)));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Description and Wicchu link copied.')),
          ),
        );
      }
      return;
    }
    if (destination == PostShareDestination.originalMedia) {
      await repository.recordPostShare(post.id).catchError((_) {});
      if (context.mounted) await _shareMedia(context, post);
      return;
    }
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
      case PostShareDestination.copyCaption:
      case PostShareDestination.originalMedia:
        return;
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
              leading: const Icon(WicchuIcons.sparkle),
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
              leading: const Icon(WicchuIcons.image),
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
              leading: const Icon(WicchuIcons.chatCircle),
              title: const Text('WhatsApp'),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.whatsapp),
            ),
            ListTile(
              leading: const Icon(WicchuIcons.facebookLogo),
              title: const Text('Facebook'),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.facebook),
            ),
            ListTile(
              leading: const Icon(WicchuIcons.export),
              title: Text(sheetContext.tr('More sharing options')),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.system),
            ),
            if (post.media.isNotEmpty)
              ListTile(
                leading: const Icon(WicchuIcons.images),
                title: Text(
                  sheetContext.tr('Create an Instagram or Facebook post'),
                ),
                subtitle: Text(
                  sheetContext.tr(
                    'Copies the description and Wicchu link automatically. Choose your social app, then paste them into your post.',
                  ),
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  PostShareDestination.originalMedia,
                ),
              ),
            ListTile(
              leading: const Icon(WicchuIcons.copy),
              title: Text(sheetContext.tr('Copy description and link')),
              onTap: () =>
                  Navigator.pop(sheetContext, PostShareDestination.copyCaption),
            ),
            ListTile(
              leading: const Icon(WicchuIcons.linkSimple),
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
