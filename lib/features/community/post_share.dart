import 'post_rules_review_page.dart';
import 'community_avatar.dart';
import '../../data/authenticated_api_client.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, debugPrint, debugPrintStack, visibleForTesting;
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

@visibleForTesting
Rect postShareOrigin(BuildContext context) {
  final viewport = Offset.zero & MediaQuery.sizeOf(context);
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox &&
      renderObject.hasSize &&
      renderObject.attached) {
    final bounds = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final visibleBounds = bounds.intersect(viewport);
    if (visibleBounds.isFinite && !visibleBounds.isEmpty) return visibleBounds;
  }
  // Feed item builders can expose RenderSliverList rather than RenderBox.
  // A small on-screen anchor also supports off-screen posts and iPad popovers.
  return Rect.fromCenter(center: viewport.center, width: 1, height: 1);
}

Rect _shareOrigin(BuildContext context) => postShareOrigin(context);

/// Confirm the clipboard write before the native sheet obscures Wicchu.
Future<bool> confirmCopiedShareCaption(
  BuildContext context,
  String caption,
) async {
  await Clipboard.setData(ClipboardData(text: caption));
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Icon(
                WicchuIcons.checkCircleFill,
                size: 22,
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dialogContext.tr('Description copied'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            dialogContext.tr(
              'We copied the text and Wicchu link. Paste them into your Instagram caption.',
            ),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                dialogContext.tr('Share on Instagram'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _shareGeneratedImage(
  BuildContext context,
  PostShareKit kit,
  String imageUrl, {
  required String title,
}) async {
  if (imageUrl.trim().isEmpty) {
    throw StateError('The social image is not available.');
  }
  final shareOrigin = _shareOrigin(context);
  final prepared = await preparePostMedia([
    MediaExportItem(url: imageUrl, type: 'image'),
  ]);
  try {
    if (!context.mounted) return;
    if (!await confirmCopiedShareCaption(context, kit.message)) return;
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        title: title,
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
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      progressOpen = false;
    }
    if (!context.mounted) return;
    if (!await confirmCopiedShareCaption(context, socialPostCaption(post))) {
      return;
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
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Post sharing failed: $error');
      debugPrintStack(stackTrace: stack);
    }
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
    if (destination == PostShareDestination.instagramFeed &&
        post.media.isNotEmpty) {
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
        return;
      case PostShareDestination.instagramFeed:
        await _shareGeneratedImage(
          context,
          kit,
          kit.instagramFeedImageUrl,
          title: context.tr('Instagram Post'),
        );
        return;
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
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Post sharing failed: $error');
      debugPrintStack(stackTrace: stack);
    }
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
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => WicchuShareSheet(
      canShareToCommunities: post.canShareToCommunities,
      hasMedia: post.media.isNotEmpty,
      onSelected: (destination) => Navigator.pop(sheetContext, destination),
    ),
  );
  if (destination == null || !context.mounted) return;
  await sharePostTo(context, repository, post, destination);
}

/// Shared destination chooser for every post surface. Export actions prepare
/// files for the system share flow; they never publish to a social account.
class WicchuShareSheet extends StatelessWidget {
  const WicchuShareSheet({
    super.key,
    required this.canShareToCommunities,
    required this.hasMedia,
    required this.onSelected,
  });

  final bool canShareToCommunities;
  final bool hasMedia;
  final ValueChanged<PostShareDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 12);

    Widget quickAction(
      String label,
      IconData icon,
      PostShareDestination target,
    ) => SizedBox(
      width: 80,
      child: InkWell(
        onTap: () => onSelected(target),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(icon, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(label),
                textAlign: TextAlign.center,
                style: subtitleStyle,
              ),
            ],
          ),
        ),
      ),
    );

    Widget option(
      String label,
      IconData icon,
      PostShareDestination target, {
      String? subtitle,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: subtitle == null ? 48 : 56,
      minVerticalPadding: 4,
      leading: Icon(icon, size: 22, color: colors.primary),
      title: Text(context.tr(label), style: titleStyle),
      subtitle: subtitle == null
          ? null
          : Text(context.tr(subtitle), style: subtitleStyle),
      trailing: const Icon(WicchuIcons.caretRight, size: 18),
      onTap: () => onSelected(target),
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Share post'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(WicchuIcons.x, size: 20),
                  ),
                ],
              ),
              Text(context.tr('Choose where to share.'), style: subtitleStyle),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                children: [
                  if (canShareToCommunities)
                    quickAction(
                      'Community',
                      WicchuIcons.usersThree,
                      PostShareDestination.community,
                    ),
                  quickAction(
                    'WhatsApp',
                    WicchuIcons.chatCircle,
                    PostShareDestination.whatsapp,
                  ),
                  quickAction(
                    'Facebook',
                    WicchuIcons.facebookLogo,
                    PostShareDestination.facebook,
                  ),
                  quickAction(
                    'More',
                    WicchuIcons.export,
                    PostShareDestination.system,
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                context.tr('Share on Instagram'),
                style: titleStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Prepare an image, then choose where to share it.'),
                style: subtitleStyle,
              ),
              option(
                'Instagram Story',
                WicchuIcons.sparkle,
                PostShareDestination.instagramStory,
                subtitle: 'Vertical image · 9:16',
              ),
              option(
                'Instagram Post',
                WicchuIcons.image,
                PostShareDestination.instagramFeed,
                subtitle: hasMedia
                    ? 'Share the original photos or videos without cropping.'
                    : 'Vertical image · 4:5',
              ),
              const Divider(height: 16),
              option(
                'Copy link',
                WicchuIcons.linkSimple,
                PostShareDestination.copyLink,
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  context.tr('More sharing options'),
                  style: titleStyle,
                ),
                children: [
                  if (hasMedia)
                    option(
                      'Share original media',
                      WicchuIcons.images,
                      PostShareDestination.originalMedia,
                    ),
                  option(
                    'Copy description and link',
                    WicchuIcons.copy,
                    PostShareDestination.copyCaption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _CommunityShareSheet(repository: repository, post: post),
    ),
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
      title: Row(
        children: [
          Icon(
            failed.isEmpty
                ? WicchuIcons.checkCircleFill
                : WicchuIcons.warningCircle,
            size: 24,
            color: failed.isEmpty
                ? Theme.of(dialogContext).colorScheme.primary
                : Theme.of(dialogContext).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dialogContext.tr(
                failed.isEmpty ? 'Publication shared' : 'Sharing results',
              ),
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (published > 0)
            _ShareResultLine(
              icon: WicchuIcons.checkCircle,
              text: dialogContext.trCount(
                published,
                singular: 'Published in {count} community',
                plural: 'Published in {count} communities',
              ),
            ),
          if (pending > 0)
            _ShareResultLine(
              icon: WicchuIcons.clock,
              text: dialogContext.trCount(
                pending,
                singular: 'Awaiting approval in {count} community',
                plural: 'Awaiting approval in {count} communities',
              ),
            ),
          for (final item in failed)
            _ShareResultLine(
              icon: WicchuIcons.warningCircle,
              error: true,
              text: item.message.isEmpty
                  ? dialogContext.tr('Sharing failed')
                  : dialogContext.tr(item.message),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.tr('Done')),
        ),
      ],
    ),
  );
}

class _ShareResultLine extends StatelessWidget {
  const _ShareResultLine({
    required this.icon,
    required this.text,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: error ? colors.error : colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
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
  final _captionFocus = FocusNode();
  final _selected = <String, String>{};
  final _joining = <String>{};
  final _choosing = <String>{};
  final _categoryNames = <String, String>{};
  late Future<List<Community>> _communities = _load();
  String _query = '';
  int _communityCount = 0;
  bool _sharing = false;
  Object? _shareError;

  Future<List<Community>> _load() async {
    final excludedCommunityIds = <String>{
      if (!widget.post.isPersonal) widget.post.communityId,
      if (widget.post.sourceCommunityId?.trim().isNotEmpty == true)
        widget.post.sourceCommunityId!,
    };
    final communities = (await widget.repository.listCommunities())
        .where(
          (item) =>
              !item.isPublicProfile && !excludedCommunityIds.contains(item.id),
        )
        .toList(growable: false);
    if (mounted) setState(() => _communityCount = communities.length);
    return communities;
  }

  @override
  void dispose() {
    _captionFocus.dispose();
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
        setState(() => _shareError = error);
      }
    } finally {
      if (mounted) setState(() => _joining.remove(community.id));
    }
  }

  Future<void> _toggle(
    Community community, {
    bool changeCategory = false,
  }) async {
    if (_sharing || _choosing.contains(community.id)) return;
    if (!changeCategory && _selected.remove(community.id) != null) {
      setState(() {});
      return;
    }
    setState(() => _choosing.add(community.id));
    try {
      final categories = await widget.repository.listCategories(community.id);
      if (!mounted) return;
      if (categories.isEmpty) {
        throw StateError('This community has no available category');
      }
      var category = categories.first;
      if (categories.length > 1) {
        final chosen = await showModalBottomSheet<CommunityCategory>(
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
        );
        if (!mounted || chosen == null) return;
        category = chosen;
      }
      setState(() {
        _selected[community.id] = category.id;
        _categoryNames[community.id] = category.name;
        _shareError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _shareError = error);
      }
    } finally {
      if (mounted) setState(() => _choosing.remove(community.id));
    }
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      final communities = await _communities;
      for (final id in _selected.keys.toList()) {
        final rules = await widget.repository.listRules(id);
        if (!mounted) return;
        if (rules.acceptanceRequired) {
          final community = communities.firstWhere((item) => item.id == id);
          final agreed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PostRulesReviewPage(
                community: community,
                repository: widget.repository,
              ),
            ),
          );
          if (!mounted || agreed != true) return;
        }
      }
      final results = await widget.repository.sharePersonalPostToCommunities(
        widget.post.id,
        categoryByCommunity: _selected,
        caption: _caption.text.trim(),
      );
      if (mounted) Navigator.pop(context, results);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _shareError = error;
      });
      if (kDebugMode) {
        debugPrint(
          'Community share failed: type=${error.runtimeType}; '
          'status=${error is ApiException ? error.statusCode : null}; $error',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final needsExpandedSheet =
        media.viewInsets.bottom > 0 ||
        media.size.height < 750 ||
        media.textScaler.scale(1) > 1.2;
    final heightFactor = needsExpandedSheet
        ? .98
        : (_communityCount > 4 ? .9 : .7);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              (media.size.height -
                      media.viewInsets.bottom -
                      media.padding.top -
                      40)
                  .clamp(0, double.infinity) *
              heightFactor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.tr('Share to Community'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                context.tr(
                  'Choose a community and category. Rules and approval still apply.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: context.tr('Close'),
                onPressed: _sharing ? null : () => Navigator.pop(context),
                icon: const Icon(WicchuIcons.x),
              ),
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
            Flexible(
              child: FutureBuilder<List<Community>>(
                future: _communities,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.trError(snapshot.error!)),
                          TextButton(
                            onPressed: () =>
                                setState(() => _communities = _load()),
                            child: Text(context.tr('Retry')),
                          ),
                        ],
                      ),
                    );
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
                  if (communities.isEmpty) {
                    return Center(
                      child: Text(context.tr('No communities found')),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: communities.length,
                    itemBuilder: (context, index) {
                      final community = communities[index];
                      final pending =
                          community.membershipStatus ==
                          MembershipStatus.pending;
                      final banned =
                          community.membershipStatus == MembershipStatus.banned;
                      return CheckboxListTile(
                        value: _selected.containsKey(community.id),
                        onChanged:
                            community.canPublish &&
                                !pending &&
                                !banned &&
                                !_sharing &&
                                !_choosing.contains(community.id)
                            ? (_) => _toggle(community)
                            : null,
                        title: Text(
                          community.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                banned
                                    ? 'Sharing unavailable'
                                    : pending
                                    ? 'Membership pending'
                                    : community.canPublish
                                    ? (community.approvalRequired
                                          ? 'Publication approval required'
                                          : 'Ready to publish')
                                    : community.isJoined
                                    ? 'Sharing unavailable'
                                    : 'Join to share',
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (_selected.containsKey(community.id))
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: _sharing
                                    ? null
                                    : () => _toggle(
                                        community,
                                        changeCategory: true,
                                      ),
                                child: Text(
                                  '${context.tr(_categoryNames[community.id] ?? '')} · ${context.tr('Change category')}',
                                ),
                              ),
                          ],
                        ),
                        secondary: !community.isJoined && !pending && !banned
                            ? TextButton(
                                onPressed:
                                    _sharing || _joining.contains(community.id)
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
                            : CommunityAvatar(community: community, radius: 20),
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
                  ListenableBuilder(
                    listenable: Listenable.merge([_captionFocus, _caption]),
                    builder: (context, _) => TextField(
                      controller: _caption,
                      focusNode: _captionFocus,
                      style: const TextStyle(fontSize: 14),
                      maxLength: 1000,
                      minLines: 1,
                      maxLines:
                          _captionFocus.hasFocus || _caption.text.isNotEmpty
                          ? 3
                          : 1,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => isFocused || currentLength > 0
                          ? Text(
                              '$currentLength/$maxLength',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : null,
                      enabled: !_sharing,
                      decoration: InputDecoration(
                        labelText: context.tr('Optional sharing caption'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_shareError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          context.trError(_shareError!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _selected.isEmpty || _sharing || _choosing.isNotEmpty
                          ? null
                          : _submit,
                      child: Text(
                        context.tr(
                          _sharing
                              ? 'Sharing…'
                              : _selected.length == 1
                              ? 'Share to 1 community'
                              : 'Share to {count} communities',
                          {'count': '${_selected.length}'},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
