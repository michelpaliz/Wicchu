import '../../widgets/category_symbol.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../theme/wicchu_theme.dart';
import '../../localization/app_language.dart';
import 'post_media_gallery.dart';
import 'comments_sheet.dart';
import '../../domain/community_repository.dart';
import 'post_markdown.dart';
import 'user_avatar.dart';
import 'report_dialog.dart';
import 'community_profile_page.dart';
import 'category_page.dart';

String formatPostTime(BuildContext context, DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt.toLocal());
  if (difference.inMinutes < 1) return context.tr('Now');
  if (difference.inHours < 1) {
    return context.tr('{count} min ago', {'count': '${difference.inMinutes}'});
  }
  if (difference.inDays < 1) {
    return context.tr('{count} h ago', {'count': '${difference.inHours}'});
  }
  if (difference.inDays == 1) return context.tr('Yesterday');
  if (difference.inDays < 7) {
    return context.tr('{count} days ago', {'count': '${difference.inDays}'});
  }
  return MaterialLocalizations.of(context).formatShortDate(createdAt.toLocal());
}

/// Adds 4dp per side to PostCard's 8dp padding for 12dp around the line.
/// Feed containers provide the shared 16dp horizontal content inset.
class PostFeedSeparator extends StatelessWidget {
  const PostFeedSeparator({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: 8,
    thickness: .5,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .12),
  );
}

class PostFeedItem extends StatelessWidget {
  const PostFeedItem({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Column(children: [child, const PostFeedSeparator()]);
}

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.category,
    required this.icon,
    required this.community,
    required this.author,
    this.authorAvatarUrl,
    this.isAnonymousAuthor = false,
    required this.time,
    required this.text,
    this.price,
    this.collapseText = true,
    this.compact = false,
    this.showCommunity = true,
    this.communityFirst = false,
    this.onCommunityTap,
    this.showActions = true,
    this.showMenu = true,
    this.likes = 0,
    this.comments = 0,
    this.showImage = false,
    this.onTap,
    this.reacted = false,
    this.onReaction,
    this.onComments,
    this.saved = false,
    this.onSaved,
    this.media = const [],
    this.onReport,
    this.onShare,
    this.promotion,
    this.onPromotionImpression,
    this.onPromotionClick,
    this.poll,
    this.onPollVote,
    this.onAuthorTap,
    this.edited = false,
    this.onEdit,
    this.onDelete,
    this.onPinnedChanged,
    this.onModerationRemove,
    this.onMentionTap,
    this.repository,
    this.post,
    this.viewerContent = false,
  });

  final CommunityRepository? repository;
  final CommunityPost? post;
  final bool viewerContent;
  final String category;
  final String icon;
  final String community;
  final String author;
  final String? authorAvatarUrl;
  final bool isAnonymousAuthor;
  final String time;
  final String text;
  final String? price;
  final bool collapseText;
  final bool compact;
  final bool showCommunity;
  final bool communityFirst;
  final VoidCallback? onCommunityTap;
  final bool showActions;
  final bool showMenu;
  final int likes;
  final int comments;
  final bool showImage;
  final VoidCallback? onTap;
  final bool reacted;
  final Future<int> Function(bool reacted)? onReaction;
  final Future<int?> Function()? onComments;
  final bool saved;
  final Future<void> Function(bool saved)? onSaved;
  final List<PostMedia> media;
  final Future<void> Function(String reason, String category, {bool? hidePost})?
  onReport;
  final Future<void> Function()? onShare;
  final PostPromotion? promotion;
  final Future<void> Function()? onPromotionImpression;
  final Future<void> Function()? onPromotionClick;
  final PostPoll? poll;
  final Future<PostPoll> Function(String optionId)? onPollVote;
  final VoidCallback? onAuthorTap;
  final bool edited;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;
  final Future<void> Function(bool pinned)? onPinnedChanged;
  final Future<void> Function(String reason)? onModerationRemove;
  final ValueChanged<String>? onMentionTap;

  Future<
    ({
      int likes,
      int comments,
      bool reacted,
      bool saved,
      bool hidden,
      PostPoll? poll,
    })
  >
  openMedia(
    BuildContext context, {
    int initialIndex = 0,
    int? currentLikes,
    int? currentComments,
    bool? currentReacted,
    bool? currentSaved,
    PostPoll? currentPoll,
  }) async {
    var count = currentLikes ?? likes;
    var commentCount = currentComments ?? comments;
    var liked = currentReacted ?? reacted;
    var isSaved = currentSaved ?? saved;
    var hidden = false;
    var latestPoll = currentPoll ?? poll;
    final cardKey = GlobalKey<_PostCardState>();
    final commentsKey = GlobalKey();
    await openPostMediaViewer(
      context,
      media,
      initialIndex: initialIndex,
      author: context.tr(author),
      actionsBuilder: (viewerContext) => IconButton(
        tooltip: viewerContext.tr('Post options'),
        icon: const Icon(WicchuIcons.dotsThree),
        onPressed: () => cardKey.currentState?._menu()._open(viewerContext),
      ),
      detailBuilder: (viewerContext, mediaWidget, scroll, physics, immersive) {
        final card = PostCard(
          key: cardKey,
          viewerContent: true,
          category: category,
          icon: icon,
          community: community,
          author: author,
          authorAvatarUrl: authorAvatarUrl,
          isAnonymousAuthor: isAnonymousAuthor,
          time: time,
          text: text,
          price: price,
          promotion: promotion,
          edited: edited,
          collapseText: false,
          compact: true,
          showCommunity: showCommunity,
          showActions: showActions,
          likes: count,
          comments: commentCount,
          reacted: liked,
          saved: isSaved,
          onAuthorTap: onAuthorTap,
          onCommunityTap: onCommunityTap,
          onMentionTap: onMentionTap,
          post: post,
          onReaction: onReaction == null
              ? null
              : (next) async {
                  count = await onReaction!(next);
                  liked = next;
                  return count;
                },
          onSaved: onSaved == null
              ? null
              : (next) async {
                  await onSaved!(next);
                  isSaved = next;
                },
          onComments: onComments == null
              ? null
              : () async {
                  if (commentsKey.currentContext != null) {
                    await Scrollable.ensureVisible(
                      commentsKey.currentContext!,
                      duration: const Duration(milliseconds: 250),
                    );
                    return commentCount;
                  }
                  return onComments!();
                },
          onShare: onShare,
          onReport: onReport == null
              ? null
              : (reason, category, {hidePost}) async {
                  await onReport!(reason, category, hidePost: hidePost);
                  if (hidePost == true) {
                    hidden = true;
                    if (viewerContext.mounted) Navigator.pop(viewerContext);
                  }
                },
          onEdit: onEdit == null
              ? null
              : () {
                  Navigator.pop(viewerContext);
                  onEdit!();
                },
          onDelete: onDelete == null
              ? null
              : () async {
                  await onDelete!();
                  if (viewerContext.mounted) Navigator.pop(viewerContext);
                },
          onPinnedChanged: onPinnedChanged,
          onModerationRemove: onModerationRemove == null
              ? null
              : (reason) async {
                  await onModerationRemove!(reason);
                  if (viewerContext.mounted) Navigator.pop(viewerContext);
                },
          poll: latestPoll,
          onPollVote: onPollVote == null
              ? null
              : (optionId) async {
                  latestPoll = await onPollVote!(optionId);
                  return latestPoll!;
                },
        );
        Widget layout(Widget comments, Widget composer) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                physics: physics,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    mediaWidget,
                    Offstage(
                      offstage: immersive,
                      child: Column(children: [card, comments]),
                    ),
                  ],
                ),
              ),
            ),
            Offstage(offstage: immersive, child: composer),
          ],
        );
        if (repository != null && post != null && onComments != null) {
          return PostComments(
            repository: repository!,
            post: post!,
            inline: true,
            layoutBuilder: (comments, composer) => layout(
              KeyedSubtree(key: commentsKey, child: comments),
              composer,
            ),
            onCountChanged: (value) {
              commentCount = value;
              final state = cardKey.currentState;
              state?._updateCommentCount(value);
            },
          );
        }
        return layout(const SizedBox.shrink(), const SizedBox.shrink());
      },
    );
    return (
      likes: count,
      comments: commentCount,
      reacted: liked,
      saved: isSaved,
      hidden: hidden,
      poll: latestPoll,
    );
  }

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _likes = widget.likes;
  late int _comments = widget.comments;
  late bool _reacted = widget.reacted;
  late bool _saved = widget.saved;
  late bool _pinned = widget.post?.pinned ?? false;
  bool _savingReaction = false;
  bool _savingPost = false;
  bool _impressionSent = false;
  late PostPoll? _poll = widget.poll;
  bool _savingVote = false;
  bool _hidden = false;
  bool _deleting = false;
  bool _moderating = false;
  bool _businessViewSent = false;

  Future<Community?>? _sourceProfile;

  void _loadSourceProfile() {
    final id = widget.post?.sourceCommunityId;
    _sourceProfile =
        !widget.isAnonymousAuthor &&
            widget.post?.isAnonymous != true &&
            id != null &&
            id.isNotEmpty &&
            widget.repository != null
        ? widget.repository!
              .getCommunity(id)
              .then<Community?>((value) => value)
              .catchError((Object _) => null)
        : null;
  }

  Future<void> _openSharedCategory() async {
    final post = widget.post;
    final repository = widget.repository;
    if (post == null || repository == null) return;
    try {
      final community = await repository.getCommunity(post.communityId);
      final categories = await repository.listCategories(post.communityId);
      final matches = categories.where(
        (category) => category.id == post.categoryId,
      );
      if (!mounted || matches.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryPage(
            community: community,
            category: matches.first,
            repository: repository,
            canPost: community.canPublish,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  void _openSourceProfile(Community profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityProfilePage(
          community: profile,
          repository: widget.repository!,
        ),
      ),
    );
  }

  Future<void> _deletePost() async {
    if (widget.onDelete == null || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(WicchuIcons.trash),
        title: Text(dialogContext.tr('Delete publication?')),
        content: Text(
          dialogContext.tr(
            'This publication will disappear from Wicchu. This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await widget.onDelete!();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _togglePinned() async {
    if (widget.onPinnedChanged == null || _savingPost) return;
    final previous = _pinned;
    setState(() {
      _pinned = !previous;
      _savingPost = true;
    });
    try {
      await widget.onPinnedChanged!(_pinned);
    } catch (error) {
      if (mounted) {
        setState(() => _pinned = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingPost = false);
    }
  }

  Future<void> _removeFromCommunity() async {
    if (widget.onModerationRemove == null || _moderating) return;
    var draftReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(WicchuIcons.trash),
          title: Text(dialogContext.tr('Remove from community?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContext.tr(
                  'This removes the post from this community. The original remains available on its source page.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                maxLength: 1000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: dialogContext.tr('Removal reason'),
                  hintText: dialogContext.tr(
                    'Explain why this post is being removed',
                  ),
                ),
                onChanged: (value) => setDialogState(() {
                  draftReason = value;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: draftReason.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, draftReason.trim()),
              child: Text(dialogContext.tr('Remove')),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _moderating = true);
    try {
      await widget.onModerationRemove!(reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Post removed from community'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _moderating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSourceProfile();
    _recordImpression();
    _recordBusinessView();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post?.sourceCommunityId != widget.post?.sourceCommunityId ||
        oldWidget.post?.isAnonymous != widget.post?.isAnonymous ||
        oldWidget.isAnonymousAuthor != widget.isAnonymousAuthor ||
        oldWidget.repository != widget.repository) {
      _loadSourceProfile();
    }
    if (oldWidget.likes != widget.likes) _likes = widget.likes;
    if (oldWidget.comments != widget.comments) _comments = widget.comments;
    if (oldWidget.reacted != widget.reacted) _reacted = widget.reacted;
    if (oldWidget.saved != widget.saved) _saved = widget.saved;
    if (oldWidget.post?.pinned != widget.post?.pinned) {
      _pinned = widget.post?.pinned ?? false;
    }
    if (oldWidget.promotion?.id != widget.promotion?.id) {
      _impressionSent = false;
      _recordImpression();
    }
    if (oldWidget.poll != widget.poll) _poll = widget.poll;
    if (oldWidget.post?.id != widget.post?.id) {
      _businessViewSent = false;
      _recordBusinessView();
    }
  }

  void _recordImpression() {
    if (_impressionSent || widget.onPromotionImpression == null) return;
    _impressionSent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.onPromotionImpression!());
    });
  }

  void _recordBusinessView() {
    final post = widget.post;
    if (_businessViewSent ||
        widget.repository == null ||
        post == null ||
        (post.todayMenu == null && post.businessFeature == null)) {
      return;
    }
    _businessViewSent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          widget.repository!
              .recordBusinessPostEngagement(post.id, action: 'view')
              .catchError((_) {}),
        );
      }
    });
  }

  Future<void> _contactBusiness() async {
    final post = widget.post;
    if (post != null && widget.repository != null) {
      await widget.repository!
          .recordBusinessPostEngagement(post.id, action: 'contact')
          .catchError((_) {});
    }
    widget.onCommunityTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final accent = categoryColor(widget.category, context);
    final theme = Theme.of(context);
    final anonymous =
        widget.isAnonymousAuthor || widget.post?.isAnonymous == true;
    final communityFirst =
        !anonymous && widget.communityFirst && widget.showCommunity;
    final authorTap = anonymous ? null : widget.onAuthorTap;
    final authorName = anonymous
        ? context.tr('Anonymous Member')
        : context.tr(widget.author);
    final interactive =
        _poll != null ||
        widget.post?.todayMenu != null ||
        widget.post?.businessFeature != null;
    final mediaLayout = widget.media.isNotEmpty && !interactive;
    final textOnly = widget.media.isEmpty && !interactive;
    final categoryLabel = context.tr(widget.category).trim();
    final showCategory =
        categoryLabel.isNotEmpty &&
        !{
          'posts',
          'publicaciones',
          'publishing',
          'general',
        }.contains(categoryLabel.toLowerCase());
    return Material(
      color: widget.viewerContent
          ? theme.colorScheme.surface
          : Colors.transparent,
      borderRadius: widget.viewerContent
          ? const BorderRadius.vertical(top: Radius.circular(24))
          : BorderRadius.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.onPromotionClick != null) {
                  unawaited(widget.onPromotionClick!());
                }
                widget.onTap!();
              },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.viewerContent ? 16 : 0,
            textOnly ? 4 : 8,
            widget.viewerContent ? 16 : 0,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pinned) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      WicchuIcons.pushPinFill,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      context.tr('Pinned publication'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (widget.promotion != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr('Sponsored'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FutureBuilder<Community?>(
                key: ValueKey('${widget.post?.sourceCommunityId}:$anonymous'),
                future: _sourceProfile,
                builder: (context, snapshot) {
                  final source = anonymous ? null : snapshot.data;
                  final primaryTap = source != null
                      ? () => _openSourceProfile(source)
                      : (communityFirst ? widget.onCommunityTap : authorTap);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: source != null ? primaryTap : authorTap,
                        customBorder: const CircleBorder(),
                        child: UserAvatar(
                          name: source?.name ?? authorName,
                          imageUrl: anonymous
                              ? null
                              : (source?.imageUrl ??
                                    (source == null
                                        ? widget.authorAvatarUrl
                                        : null)),
                          radius: 18,
                          backgroundColor: accent.withValues(alpha: .14),
                          foregroundColor: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: primaryTap,
                              child: Text(
                                source?.name ??
                                    (communityFirst
                                        ? widget.community
                                        : authorName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: WicchuPostTypography.author(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (source != null)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: authorTap,
                                    child: Text(
                                      authorName,
                                      style: WicchuPostTypography.metadata(
                                        context,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    ' · ${widget.time}${widget.edited ? ' · ${context.tr('Edited')}' : ''}',
                                    style: WicchuPostTypography.metadata(
                                      context,
                                    ),
                                  ),
                                  if (showCategory)
                                    InkWell(
                                      onTap: _openSharedCategory,
                                      child: Text(
                                        ' · $categoryLabel',
                                        style: WicchuPostTypography.metadata(
                                          context,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            else
                              InkWell(
                                onTap: source != null || communityFirst
                                    ? authorTap
                                    : null,
                                child: Text(
                                  '${source != null || communityFirst ? '$authorName · ' : ''}${widget.time}${widget.edited ? ' · ${context.tr('Edited')}' : ''}${source == null && widget.showCommunity && !communityFirst && !anonymous ? ' · ${widget.community}' : ''}${showCategory ? ' · $categoryLabel' : ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: WicchuPostTypography.metadata(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!widget.viewerContent && widget.showMenu) _menu(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              if (mediaLayout) ...[
                PostMediaGallery(media: widget.media, onOpen: _openMedia),
                if (widget.showActions) _engagementActions(),
                const SizedBox(height: 6),
                _postContent(),
              ] else ...[
                _postContent(),
                if (widget.media.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  PostMediaGallery(media: widget.media, onOpen: _openMedia),
                ],
                if (_poll != null) ...[
                  const SizedBox(height: 8),
                  DefaultTextStyle.merge(
                    style: WicchuPostTypography.body(context),
                    child: _PollView(
                      poll: _poll!,
                      enabled: widget.onPollVote != null,
                      saving: _savingVote,
                      onSelected: _vote,
                    ),
                  ),
                ],
                if (widget.showActions)
                  _engagementActions(compact: textOnly || _poll != null),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _postContent() => DefaultTextStyle.merge(
    style: WicchuPostTypography.body(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.post?.todayMenu case final menu?)
          _TodayMenuView(menu: menu)
        else if (widget.post?.businessFeature case final feature?)
          _BusinessFeatureView(feature: feature)
        else if (widget.text.isNotEmpty)
          PostMarkdown(
            data: widget.text,
            bodyStyle: _poll == null
                ? null
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 19 / 15,
                  ),
            collapsible: widget.collapseText,
            compact: true,
            previewLines: 3,
            onUserTap: widget.onMentionTap,
          ),
        if (widget.post?.todayMenu != null ||
            widget.post?.businessFeature != null)
          _businessFooter(),
        if (widget.price != null) ...[
          const SizedBox(height: 4),
          Text(widget.price!, style: WicchuPostTypography.title(context)),
        ],
      ],
    ),
  );

  Widget _engagementActions({bool compact = false}) => Row(
    children: [
      _PostAction(
        compact: compact,
        icon: _reacted ? WicchuIcons.heartFill : WicchuIcons.heart,
        value: '$_likes',
        tooltip: context.tr(_reacted ? 'Unlike' : 'Like'),
        color: _reacted ? const Color(0xFFE53945) : null,
        onTap: widget.onReaction == null || _savingReaction
            ? null
            : _toggleReaction,
      ),
      const SizedBox(width: 12),
      _PostAction(
        compact: compact,
        icon: WicchuIcons.chatCircle,
        value: '$_comments',
        tooltip: context.tr('Comments'),
        onTap: widget.onComments == null ? null : _openComments,
      ),
      const SizedBox(width: 12),
      _PostAction(
        compact: compact,
        icon: WicchuIcons.shareNetwork,
        tooltip: context.tr('Share'),
        value: null,
        onTap: widget.onShare,
      ),
      const Spacer(),
      if (widget.onSaved != null)
        _PostAction(
          compact: compact,
          icon: _saved ? WicchuIcons.bookmarkFill : WicchuIcons.bookmark,
          tooltip: context.tr(_saved ? 'Unsave post' : 'Save'),
          onTap: _savingPost ? null : _toggleSaved,
        ),
    ],
  );

  _PostMenu _menu() => _PostMenu(
    category: widget.category,
    categoryIcon: widget.icon,
    media: widget.media,
    ownedByMe:
        widget.post?.ownedByMe ??
        (widget.onEdit != null || widget.onDelete != null),
    onShare: widget.onShare,
    saved: _saved,
    saving: _savingPost || _deleting || _moderating,
    onSave: widget.onSaved == null ? null : _toggleSaved,
    onReport: widget.onReport == null ? null : _report,
    onEdit: widget.onEdit,
    onDelete: widget.onDelete == null ? null : _deletePost,
    pinned: _pinned,
    personalPin: widget.post?.isPersonal == true,
    onPin: widget.onPinnedChanged == null ? null : _togglePinned,
    onModerationRemove: widget.onModerationRemove == null
        ? null
        : _removeFromCommunity,
  );

  Widget _businessFooter() {
    final post = widget.post!;
    final menuExpired = post.todayMenu?.isExpired == true;
    final feature = post.businessFeature;
    final featureExpired = feature?.isExpired == true;
    final status = menuExpired
        ? 'Expired'
        : featureExpired
        ? (feature?.type == BusinessPostFeatureType.transportTrip
              ? 'Departed'
              : 'Expired')
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(WicchuIcons.clockCounterClockwise, size: 16),
                label: Text(context.tr(status)),
              ),
            ),
          if (widget.onCommunityTap != null)
            OutlinedButton.icon(
              onPressed: _contactBusiness,
              icon: const Icon(WicchuIcons.storefront),
              label: Text(context.tr('Contact business')),
            ),
          if (post.ownedByMe)
            Text(
              context.tr('{views} views · {contacts} contact taps', {
                'views': '${post.businessViewCount}',
                'contacts': '${post.businessContactCount}',
              }),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _openMedia(int index) async {
    final result = await widget.openMedia(
      context,
      initialIndex: index,
      currentLikes: _likes,
      currentComments: _comments,
      currentReacted: _reacted,
      currentSaved: _saved,
      currentPoll: _poll,
    );
    if (mounted) {
      setState(() {
        _likes = result.likes;
        _comments = result.comments;
        _reacted = result.reacted;
        _saved = result.saved;
        _hidden = result.hidden;
        _poll = result.poll;
      });
    }
  }

  void _updateCommentCount(int value) {
    if (mounted) setState(() => _comments = value);
  }

  Future<void> _vote(String optionId) async {
    if (widget.onPollVote == null) return;
    setState(() => _savingVote = true);
    try {
      final poll = await widget.onPollVote!(optionId);
      if (mounted) setState(() => _poll = poll);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingVote = false);
    }
  }

  Future<void> _toggleReaction() async {
    final next = !_reacted;
    setState(() => _savingReaction = true);
    try {
      final count = await widget.onReaction!(next);
      if (mounted) {
        setState(() {
          _reacted = next;
          _likes = count;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingReaction = false);
    }
  }

  Future<void> _openComments() async {
    final count = await widget.onComments!();
    if (mounted && count != null) setState(() => _comments = count);
  }

  Future<void> _toggleSaved() async {
    final next = !_saved;
    setState(() => _savingPost = true);
    try {
      await widget.onSaved!(next);
      if (mounted) setState(() => _saved = next);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingPost = false);
    }
  }

  Future<void> _report() async {
    final report = await showContentReportDialog(context, title: 'Report post');
    if (report == null || !mounted) return;
    try {
      await widget.onReport!(report.$1, report.$2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Report submitted')),
            action: SnackBarAction(
              label: context.tr('Hide post'),
              onPressed: () async {
                try {
                  await widget.onReport!(report.$1, report.$2, hidePost: true);
                  if (mounted) setState(() => _hidden = true);
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.trError(error))),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }
}

class _TodayMenuView extends StatelessWidget {
  const _TodayMenuView({required this.menu});

  final TodayMenu menu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(WicchuIcons.forkKnife, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr("Today's menu"),
                  style: WicchuPostTypography.title(context),
                ),
              ),
              Text(
                context.tr('Available today'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final dish in menu.dishes)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(
                    dish.available
                        ? WicchuIcons.checkCircle
                        : WicchuIcons.minusCircle,
                    size: 17,
                    color: dish.available
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dish.name,
                      style: TextStyle(
                        decoration: dish.available
                            ? null
                            : TextDecoration.lineThrough,
                        color: dish.available ? null : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (dish.price.isNotEmpty)
                    Text(
                      dish.price,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          if (menu.fulfillmentOptions.isNotEmpty) ...[
            const Divider(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final option in menu.fulfillmentOptions)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(switch (option) {
                      BusinessFulfillmentOption.delivery => WicchuIcons.moped,
                      BusinessFulfillmentOption.pickup => WicchuIcons.tote,
                      BusinessFulfillmentOption.eatIn => WicchuIcons.forkKnife,
                    }, size: 16),
                    label: Text(context.tr(option.label)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BusinessFeatureView extends StatelessWidget {
  const _BusinessFeatureView({required this.feature});

  final BusinessPostFeature feature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = <(IconData, String)>[];
    switch (feature.type) {
      case BusinessPostFeatureType.retailOffer:
        details.add((WicchuIcons.package, feature.title));
      case BusinessPostFeatureType.transportTrip:
        details.add((
          WicchuIcons.path,
          '${feature.routeFrom} → ${feature.routeTo}',
        ));
        if (feature.departureAt != null) {
          final local = feature.departureAt!.toLocal();
          details.add((
            WicchuIcons.clock,
            '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
          ));
        }
        details.add((
          WicchuIcons.armchair,
          context.tr('{count} seats available', {
            'count': '${feature.seatsAvailable ?? 0}',
          }),
        ));
      case BusinessPostFeatureType.realEstateListing:
        details.add((WicchuIcons.buildings, feature.title));
        details.add((
          WicchuIcons.key,
          context.tr(feature.listingType == 'rent' ? 'For rent' : 'For sale'),
        ));
        details.add((
          WicchuIcons.bed,
          context.tr('{count} bedrooms', {'count': '${feature.bedrooms ?? 0}'}),
        ));
        details.add((WicchuIcons.mapPin, feature.location));
      case BusinessPostFeatureType.professionalService:
        details.add((WicchuIcons.briefcase, feature.title));
        details.add((WicchuIcons.mapTrifold, feature.serviceArea));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_featureIcon, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(_featureTitle),
                  style: WicchuPostTypography.title(context),
                ),
              ),
              if (feature.price.isNotEmpty)
                Text(feature.price, style: WicchuPostTypography.title(context)),
            ],
          ),
          const SizedBox(height: 10),
          for (final detail in details)
            if (detail.$2.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(detail.$1, size: 17, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(detail.$2)),
                  ],
                ),
              ),
          if (feature.type != BusinessPostFeatureType.transportTrip) ...[
            const SizedBox(height: 2),
            Text(
              context.tr(
                feature.available ? 'Currently available' : 'Unavailable',
              ),
              style: TextStyle(
                color: feature.available ? scheme.primary : scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (feature.fulfillmentOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              children: [
                for (final option in feature.fulfillmentOptions)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(context.tr(option.label)),
                  ),
              ],
            ),
          ],
          if (feature.type == BusinessPostFeatureType.professionalService)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.tr('Open the business profile to request a quote.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String get _featureTitle => switch (feature.type) {
    BusinessPostFeatureType.retailOffer => 'Product or offer',
    BusinessPostFeatureType.transportTrip => 'Trip availability',
    BusinessPostFeatureType.realEstateListing => 'Property listing',
    BusinessPostFeatureType.professionalService => 'Professional service',
  };

  IconData get _featureIcon => switch (feature.type) {
    BusinessPostFeatureType.retailOffer => WicchuIcons.tag,
    BusinessPostFeatureType.transportTrip => WicchuIcons.bus,
    BusinessPostFeatureType.realEstateListing => WicchuIcons.buildings,
    BusinessPostFeatureType.professionalService => WicchuIcons.briefcase,
  };
}

class _PollView extends StatefulWidget {
  const _PollView({
    required this.poll,
    required this.enabled,
    required this.saving,
    required this.onSelected,
  });
  final PostPoll poll;
  final bool enabled;
  final bool saving;
  final ValueChanged<String> onSelected;

  @override
  State<_PollView> createState() => _PollViewState();
}

class _PollViewState extends State<_PollView> {
  String? _selection;
  bool _previewResults = false;

  @override
  void didUpdateWidget(covariant _PollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.poll.options.any((option) => option.id == _selection)) {
      _selection = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final total = poll.totalVotes;
    final voted = poll.selectedOptionId != null;
    final results = voted || _previewResults;
    final canSelect = widget.enabled && !widget.saving && !results;
    final selected = voted ? poll.selectedOptionId : _selection;
    final colors = Theme.of(context).colorScheme;
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (canSelect) setState(() => _selection = value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: selected == option.id
                    ? colors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: canSelect
                      ? () => setState(() => _selection = option.id)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: option.id,
                          enabled: canSelect,
                          activeColor: colors.primary,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(option.text)),
                                    if (results) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        total == 0
                                            ? '0%'
                                            : '${(option.voteCount * 100 / total).round()}%',
                                      ),
                                    ],
                                  ],
                                ),
                                if (results && total > 0) ...[
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: option.voteCount / total,
                                    minHeight: 3,
                                    color: colors.primary,
                                    backgroundColor:
                                        colors.surfaceContainerHighest,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.tr(
                        total == 1 ? '{count} vote' : '{count} votes',
                        {'count': '$total'},
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!voted) ...[
                      const Text('·'),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: const TextStyle(fontSize: 12),
                          minimumSize: const Size(0, 40),
                        ),
                        onPressed: widget.saving
                            ? null
                            : () => setState(
                                () => _previewResults = !_previewResults,
                              ),
                        child: Text(
                          context.tr(results ? 'Back' : 'View results'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!voted && widget.enabled && !results) ...[
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _selection == null || widget.saving
                      ? null
                      : () => widget.onSelected(_selection!),
                  child: Text(context.tr(widget.saving ? 'Voting…' : 'Vote')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    this.value,
    this.compact = false,
    required this.tooltip,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final bool compact;
  final String? value;
  final String tooltip;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: value == null ? tooltip : '$tooltip, $value',
    excludeSemantics: true,
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            minHeight: compact ? 44 : 48,
            minWidth: 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              if (value != null) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WicchuPostTypography.metadata(
                      context,
                    ).copyWith(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({
    required this.category,
    required this.categoryIcon,
    required this.saved,
    required this.saving,
    this.media = const [],
    required this.ownedByMe,
    this.onShare,
    this.onSave,
    this.onReport,
    this.onEdit,
    this.onDelete,
    required this.pinned,
    required this.personalPin,
    this.onPin,
    this.onModerationRemove,
  });

  final List<PostMedia> media;
  final bool ownedByMe;
  final Future<void> Function()? onShare;
  final String category;
  final String categoryIcon;
  final bool saved;
  final bool saving;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool pinned;
  final bool personalPin;
  final VoidCallback? onPin;
  final VoidCallback? onModerationRemove;

  Future<void> _open(BuildContext context) async {
    final action = await showModalBottomSheet<_PostMenuAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        final preview = media
            .where(
              (item) =>
                  item.type != 'video' ||
                  (item.thumbnailUrl?.isNotEmpty ?? false),
            )
            .firstOrNull;
        Widget fallback() => Container(
          color: colors.primary.withValues(alpha: .08),
          alignment: Alignment.center,
          child: CategorySymbol(categoryIcon, size: 24),
        );
        Widget option(
          _PostMenuAction action,
          IconData icon,
          String label,
          String subtitle, {
          Color? tint,
          bool destructive = false,
        }) {
          final color = tint ?? colors.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: destructive
                  ? colors.error.withValues(alpha: .045)
                  : colors.onSurface.withValues(alpha: .025),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                title: Text(
                  sheetContext.tr(label),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: destructive ? colors.error : colors.onSurface,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    sheetContext.tr(subtitle),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                trailing: Icon(
                  WicchuIcons.caretRight,
                  size: 20,
                  color: destructive ? colors.error : colors.onSurfaceVariant,
                ),
                onTap: () => Navigator.pop(sheetContext, action),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: preview == null
                              ? fallback()
                              : Image.network(
                                  preview.previewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => fallback(),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sheetContext.tr('Post options'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sheetContext.tr('Manage this post'),
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                CategorySymbol(
                                  categoryIcon,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    sheetContext.tr(category),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                        style: IconButton.styleFrom(
                          backgroundColor: colors.onSurface.withValues(
                            alpha: .04,
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(WicchuIcons.x, size: 22),
                      ),
                    ],
                  ),
                ),
                if (onSave != null)
                  option(
                    _PostMenuAction.save,
                    saved ? WicchuIcons.bookmarkFill : WicchuIcons.bookmark,
                    saved ? 'Unsave post' : 'Save post',
                    saved
                        ? 'Remove it from your saved posts'
                        : 'Save it to view later',
                  ),
                if (onShare != null)
                  option(
                    _PostMenuAction.share,
                    WicchuIcons.export,
                    'Share post',
                    'Share it in other apps',
                  ),
                if (onPin != null)
                  option(
                    _PostMenuAction.pin,
                    pinned ? WicchuIcons.pushPinFill : WicchuIcons.pushPin,
                    pinned ? 'Unpin publication' : 'Pin publication',
                    personalPin
                        ? (pinned
                              ? 'Remove it from the top of your profile'
                              : 'Keep it at the top of your profile')
                        : (pinned
                              ? 'Remove it from the top of its category'
                              : 'Keep it at the top of its category'),
                  ),
                if (ownedByMe && onEdit != null)
                  option(
                    _PostMenuAction.edit,
                    WicchuIcons.pencilSimple,
                    'Edit post',
                    'Update your post',
                    tint: const Color(0xff1769aa),
                  ),
                if ((ownedByMe && onDelete != null) ||
                    onModerationRemove != null ||
                    (!ownedByMe && onReport != null))
                  const Divider(height: 24),
                if (onModerationRemove != null)
                  option(
                    _PostMenuAction.moderationRemove,
                    WicchuIcons.trash,
                    'Remove from community',
                    'The original stays on its source page',
                    tint: colors.error,
                    destructive: true,
                  ),
                if (ownedByMe && onDelete != null)
                  option(
                    _PostMenuAction.delete,
                    WicchuIcons.trash,
                    'Delete publication',
                    'It will be permanently deleted',
                    tint: colors.error,
                    destructive: true,
                  ),
                if (!ownedByMe && onReport != null)
                  option(
                    _PostMenuAction.report,
                    WicchuIcons.flag,
                    'Report post',
                    'Report inappropriate content',
                    tint: const Color(0xffbf510d),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted) return;
    switch (action) {
      case _PostMenuAction.share:
        await onShare?.call();
      case _PostMenuAction.save:
        onSave?.call();
      case _PostMenuAction.report:
        onReport?.call();
      case _PostMenuAction.edit:
        onEdit?.call();
      case _PostMenuAction.pin:
        onPin?.call();
      case _PostMenuAction.delete:
        onDelete?.call();
      case _PostMenuAction.moderationRemove:
        onModerationRemove?.call();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr('More options'),
    onPressed: saving ? null : () => _open(context),
    icon: saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(WicchuIcons.dotsThree),
  );
}

enum _PostMenuAction {
  save,
  share,
  pin,
  edit,
  delete,
  report,
  moderationRemove,
}
