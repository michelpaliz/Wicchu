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
  community,
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
    if (destination == PostShareDestination.community) {
      await _shareToCommunities(context, repository, post);
      return;
    }
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
      case PostShareDestination.community:
        return;
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
            if (post.isPersonal)
              ListTile(
                leading: const Icon(WicchuIcons.usersThree),
                title: Text(sheetContext.tr('Share to Community')),
                subtitle: Text(
                  sheetContext.tr(
                    'Publish this original publication in joined communities.',
                  ),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, PostShareDestination.community),
              ),
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

Future<void> _shareToCommunities(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post,
) async {
  final results = await showModalBottomSheet<List<CommunityShareResult>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CommunityShareSheet(repository: repository, post: post),
  );
  if (results == null || !context.mounted) return;
  final published = results.where((item) => item.status == 'published').length;
  final pending = results
      .where((item) => item.status == 'pending_approval')
      .length;
  final failed = results.where((item) => !item.succeeded).toList();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr('Sharing results')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (published > 0) Text(dialogContext.tr('$published published')),
          if (pending > 0)
            Text(dialogContext.tr('$pending awaiting community approval')),
          for (final item in failed)
            Text(
              item.message.isEmpty
                  ? dialogContext.tr('Sharing failed')
                  : item.message,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.tr('Done')),
        ),
      ],
    ),
  );
}

class _CommunityShareSheet extends StatefulWidget {
  const _CommunityShareSheet({required this.repository, required this.post});
  final CommunityRepository repository;
  final CommunityPost post;

  @override
  State<_CommunityShareSheet> createState() => _CommunityShareSheetState();
}

class _CommunityShareSheetState extends State<_CommunityShareSheet> {
  final _caption = TextEditingController();
  final _selected = <String, String>{};
  final _joining = <String>{};
  late Future<List<Community>> _communities = _load();
  String _query = '';
  bool _sharing = false;

  Future<List<Community>> _load() async =>
      (await widget.repository.listCommunities())
          .where((item) => !item.isPublicProfile)
          .toList(growable: false);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _join(Community community) async {
    setState(() => _joining.add(community.id));
    try {
      await widget.repository.joinCommunity(community.id);
      if (mounted) setState(() => _communities = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _joining.remove(community.id));
    }
  }

  Future<void> _toggle(Community community) async {
    if (_selected.remove(community.id) != null) {
      setState(() {});
      return;
    }
    try {
      final categories = await widget.repository.listCategories(community.id);
      if (!mounted) return;
      if (categories.isEmpty) {
        throw StateError('This community has no available category');
      }
      var category = categories.first;
      if (categories.length > 1) {
        category =
            await showModalBottomSheet<CommunityCategory>(
              context: context,
              showDragHandle: true,
              builder: (sheetContext) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(title: Text(sheetContext.tr('Choose a category'))),
                    for (final item in categories)
                      ListTile(
                        leading: Text(item.icon),
                        title: Text(sheetContext.tr(item.name)),
                        onTap: () => Navigator.pop(sheetContext, item),
                      ),
                  ],
                ),
              ),
            ) ??
            category;
      }
      setState(() => _selected[community.id] = category.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final results = await widget.repository.sharePersonalPostToCommunities(
        widget.post.id,
        categoryByCommunity: _selected,
        caption: _caption.text.trim(),
      );
      if (mounted) Navigator.pop(context, results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: Column(
      children: [
        ListTile(
          title: Text(
            context.tr('Share to Community'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(context.tr('${_selected.length} selected')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(WicchuIcons.magnifyingGlass),
              hintText: context.tr('Search communities'),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Community>>(
            future: _communities,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(context.trError(snapshot.error!)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final communities = snapshot.data!
                  .where(
                    (item) =>
                        _query.isEmpty ||
                        item.name.toLowerCase().contains(_query),
                  )
                  .toList();
              return ListView.builder(
                itemCount: communities.length,
                itemBuilder: (context, index) {
                  final community = communities[index];
                  final pending =
                      community.membershipStatus == MembershipStatus.pending;
                  final banned =
                      community.membershipStatus == MembershipStatus.banned;
                  return CheckboxListTile(
                    value: _selected.containsKey(community.id),
                    onChanged: community.canPublish
                        ? (_) => _toggle(community)
                        : null,
                    title: Text(community.name),
                    subtitle: Text(
                      context.tr(
                        banned
                            ? 'Sharing unavailable'
                            : pending
                            ? 'Membership pending'
                            : community.canPublish
                            ? (community.approvalRequired
                                  ? 'Publication approval required'
                                  : 'Ready to publish')
                            : 'Join to share',
                      ),
                    ),
                    secondary: !community.isJoined && !pending && !banned
                        ? TextButton(
                            onPressed: _joining.contains(community.id)
                                ? null
                                : () => _join(community),
                            child: _joining.contains(community.id)
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(context.tr('Join')),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              TextField(
                controller: _caption,
                maxLength: 1000,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.tr('Optional sharing caption'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty || _sharing ? null : _submit,
                  child: Text(
                    context.tr(
                      _sharing
                          ? 'Sharing…'
                          : 'Share to ${_selected.length} communities',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
