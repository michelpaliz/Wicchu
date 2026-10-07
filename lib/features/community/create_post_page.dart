import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../widgets/responsive_side_panel.dart';
import 'post_rich_text_editor.dart';
import 'post_share.dart';
import 'post_media_gallery.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.community,
    required this.repository,
    this.initialCategory,
    this.categories = const [],
    this.existingPost,
  });

  final Community community;
  final CommunityRepository repository;
  final CommunityCategory? initialCategory;
  final List<CommunityCategory> categories;
  final CommunityPost? existingPost;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

Future<CommunityPost?> openPostComposer(
  BuildContext context, {
  required Community community,
  required CommunityRepository repository,
  CommunityCategory? initialCategory,
  List<CommunityCategory> categories = const [],
  CommunityPost? existingPost,
}) {
  final page = CreatePostPage(
    community: community,
    repository: repository,
    initialCategory: initialCategory,
    categories: categories,
    existingPost: existingPost,
  );
  if (MediaQuery.sizeOf(context).width < webDesktopBreakpoint) {
    return Navigator.push<CommunityPost>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
  return showGeneralDialog<CommunityPost>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 560,
          height: double.infinity,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 18,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            child: page,
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
  );
}

class _CreatePostPageState extends State<CreatePostPage> {
  late final Future<WicchuProfile> _postingAuthor = widget.repository
      .getProfile();
  CommunityCategory? _category;
  late final PostTextController _textController;
  bool _saving = false;
  bool _uploading = false;
  final _attachments = <_PostAttachment>[];
  late final Set<String> _mentionedUserIds = {
    ...?widget.existingPost?.mentionedUserIds,
  };
  bool _hasPoll = false;
  late bool _publishAnonymously = widget.existingPost?.isAnonymous ?? false;
  final _pollControllers = [TextEditingController(), TextEditingController()];
  final _menuDishes = [_MenuDishDraft()];
  late final Set<BusinessFulfillmentOption> _menuFulfillment = {
    ...widget.community.businessFulfillmentOptions,
  };
  final _featureTitle = TextEditingController();
  final _featurePrice = TextEditingController();
  final _featureFrom = TextEditingController();
  final _featureTo = TextEditingController();
  final _featureNumber = TextEditingController();
  final _featureLocation = TextEditingController();
  final _featureServiceArea = TextEditingController();
  bool _featureAvailable = true;
  String _propertyListingType = 'rent';
  DateTime _featureDepartureAt = DateTime.now().add(const Duration(hours: 1));
  int _step = 0;
  _PostKind _kind = _PostKind.text;
  CommunityPost? _publishedPost;
  bool get _isEditing => widget.existingPost != null;
  bool get _pollLocked => (widget.existingPost?.poll?.totalVotes ?? 0) > 0;
  bool get _canPublishAsAdmin => const {
    CommunityRole.owner,
    CommunityRole.admin,
    CommunityRole.moderator,
  }.contains(widget.community.myRole);
  bool get _canPublishAnonymously => widget.community.myRole != null;
  bool get _canPublishTodayMenu =>
      widget.community.isPublicProfile &&
      widget.community.profileCategory == ProfileCategory.localBusiness &&
      widget.community.businessServices.contains(BusinessService.food);

  bool _hasBusinessService(BusinessService service) =>
      widget.community.isPublicProfile &&
      widget.community.profileCategory == ProfileCategory.localBusiness &&
      widget.community.businessServices.contains(service);

  bool get _isStructuredBusinessPost => const {
    _PostKind.todayMenu,
    _PostKind.retailOffer,
    _PostKind.transportTrip,
    _PostKind.realEstate,
    _PostKind.professionalService,
  }.contains(_kind);

  String get _effectiveText => switch (_kind) {
    _PostKind.todayMenu => _todayMenuPostText(),
    _PostKind.retailOffer => _retailOfferPostText(),
    _PostKind.transportTrip => _transportTripPostText(),
    _PostKind.realEstate => _realEstatePostText(),
    _PostKind.professionalService => _professionalServicePostText(),
    _ => _textController.document.toPlainText().trim(),
  };

  bool get _validTodayMenu =>
      _kind != _PostKind.todayMenu ||
      (_menuDishes.isNotEmpty &&
          _menuDishes.every((dish) => dish.name.text.trim().isNotEmpty));

  bool get _validBusinessFeature => switch (_kind) {
    _PostKind.retailOffer || _PostKind.professionalService =>
      _featureTitle.text.trim().isNotEmpty &&
          (_kind != _PostKind.professionalService ||
              _featureServiceArea.text.trim().isNotEmpty),
    _PostKind.transportTrip =>
      _featureFrom.text.trim().isNotEmpty &&
          _featureTo.text.trim().isNotEmpty &&
          (int.tryParse(_featureNumber.text.trim()) ?? -1) >= 0 &&
          _featureDepartureAt.isAfter(DateTime.now()),
    _PostKind.realEstate =>
      _featureTitle.text.trim().isNotEmpty &&
          _featurePrice.text.trim().isNotEmpty &&
          _featureLocation.text.trim().isNotEmpty &&
          (int.tryParse(_featureNumber.text.trim()) ?? -1) >= 0,
    _ => true,
  };

  Future<void> _chooseMentions() async {
    final members = (await widget.repository.listMembers(widget.community.id))
        .where((member) => !member.isAnonymous && member.userId.isNotEmpty)
        .toList(growable: false);
    if (!mounted) return;
    final selected = {..._mentionedUserIds};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                ListTile(
                  title: Text(context.tr('Tag')),
                  subtitle: Text(
                    context.tr(
                      'Tagged members receive a notification when the post is published.',
                    ),
                  ),
                  trailing: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    child: Text(context.tr('Done')),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return CheckboxListTile(
                        value: selected.contains(member.userId),
                        title: Text(member.name),
                        secondary: CircleAvatar(
                          backgroundImage: member.avatarUrl == null
                              ? null
                              : NetworkImage(member.avatarUrl!),
                          child: member.avatarUrl == null
                              ? Text(member.name.characters.firstOrNull ?? '?')
                              : null,
                        ),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            if (selected.length < 20) {
                              selected.add(member.userId);
                            }
                          } else {
                            selected.remove(member.userId);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final newlySelected = result.difference(_mentionedUserIds);
    for (final userId in newlySelected) {
      final member = members.where((item) => item.userId == userId).firstOrNull;
      if (member != null) {
        _textController.insertMention(member.userId, member.name);
      }
    }
    setState(() {
      _mentionedUserIds
        ..clear()
        ..addAll(result);
    });
  }

  @override
  void initState() {
    super.initState();
    final existingPost = widget.existingPost;
    _textController = PostTextController(existingPost?.text ?? '');
    _textController.addListener(_refreshValidity);
    _category = existingPost == null
        ? widget.initialCategory ?? widget.categories.firstOrNull
        : widget.categories
              .where((category) => category.id == existingPost.categoryId)
              .firstOrNull;
    if (existingPost != null) {
      _attachments.addAll(
        existingPost.media.map((media) => _PostAttachment(media, null)),
      );
      if (existingPost.todayMenu case final menu?) {
        _kind = _PostKind.todayMenu;
        for (final dish in _menuDishes) {
          dish.dispose();
        }
        _menuDishes
          ..clear()
          ..addAll(
            menu.dishes.map(
              (dish) => _MenuDishDraft(
                name: dish.name,
                price: dish.price,
                available: dish.available,
              ),
            ),
          );
        _menuFulfillment
          ..clear()
          ..addAll(menu.fulfillmentOptions);
      } else if (existingPost.businessFeature case final feature?) {
        _kind = switch (feature.type) {
          BusinessPostFeatureType.retailOffer => _PostKind.retailOffer,
          BusinessPostFeatureType.transportTrip => _PostKind.transportTrip,
          BusinessPostFeatureType.realEstateListing => _PostKind.realEstate,
          BusinessPostFeatureType.professionalService =>
            _PostKind.professionalService,
        };
        _featureTitle.text = feature.title;
        _featurePrice.text = feature.price;
        _featureFrom.text = feature.routeFrom;
        _featureTo.text = feature.routeTo;
        _featureNumber.text =
            (feature.seatsAvailable ?? feature.bedrooms)?.toString() ?? '';
        _featureLocation.text = feature.location;
        _featureServiceArea.text = feature.serviceArea;
        _featureAvailable = feature.available;
        _propertyListingType = feature.listingType.isEmpty
            ? 'rent'
            : feature.listingType;
        _featureDepartureAt = feature.departureAt ?? _featureDepartureAt;
        _menuFulfillment
          ..clear()
          ..addAll(feature.fulfillmentOptions);
      } else if (existingPost.poll != null) {
        _hasPoll = true;
        _kind = _PostKind.poll;
        for (final controller in _pollControllers) {
          controller.dispose();
        }
        _pollControllers
          ..clear()
          ..addAll(
            existingPost.poll!.options.map(
              (option) => TextEditingController(text: option.text),
            ),
          );
      } else if (existingPost.media.isNotEmpty) {
        _kind = _PostKind.media;
      }
    }
  }

  void _refreshValidity() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    if (!widget.community.canPublish ||
        _saving ||
        _uploading ||
        _category == null ||
        _effectiveText.isEmpty ||
        _textController.exceedsCharacterLimit) {
      return false;
    }
    if (!_validTodayMenu) return false;
    if (!_validBusinessFeature) return false;
    if (!_hasPoll) return true;
    final options = _pollControllers
        .map((controller) => controller.text.trim())
        .toList();
    return options.length >= 2 &&
        options.every((option) => option.isNotEmpty) &&
        options.toSet().length == options.length;
  }

  @override
  void dispose() {
    _textController.removeListener(_refreshValidity);
    _textController.dispose();
    for (final controller in _pollControllers) {
      controller.dispose();
    }
    for (final dish in _menuDishes) {
      dish.dispose();
    }
    _featureTitle.dispose();
    _featurePrice.dispose();
    _featureFrom.dispose();
    _featureTo.dispose();
    _featureNumber.dispose();
    _featureLocation.dispose();
    _featureServiceArea.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.community.canPublish) return _permissionDenied(context);
    if (_publishedPost case final post?) return _successScreen(context, post);
    final categories =
        widget.categories.isEmpty && widget.initialCategory != null
        ? [widget.initialCategory!]
        : widget.categories;
    return PopScope(
      canPop: _step == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && !_saving) {
          setState(() => _step--);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: _saving
                ? null
                : _step == 0
                ? () => Navigator.pop(context)
                : () => setState(() => _step--),
          ),
          title: Text(
            context.tr(_isEditing ? 'Edit post' : 'Create post'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: [
            _stepProgress(context),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: ListView(
                  key: ValueKey(_step),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    switch (_step) {
                      0 => _typeStep(context, categories),
                      1 => _contentStep(context),
                      2 => _optionsStep(context),
                      _ => _previewStep(context),
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _stepNavigation(context),
      ),
    );
  }

  Widget _permissionDenied(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Create post'))),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.tr('You do not have permission to publish in this space.'),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _stepProgress(BuildContext context) {
    final labels = ['Type', 'Content', 'Options', 'Preview'];
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: context.tr('Step {current} of {total}', {
        'current': '${_step + 1}',
        'total': '4',
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index <= _step
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index <= _step
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(labels[index]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: index == _step
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: index == _step
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 12,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: index < _step ? colors.primary : colors.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeStep(BuildContext context, List<CommunityCategory> categories) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('What would you like to share?'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(context.tr('Choose a format. You can adjust it later.')),
          const SizedBox(height: 18),
          _postingDestination(context),
          const SizedBox(height: 16),
          DropdownButtonFormField<CommunityCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('Category')),
            items: [
              for (final item in categories)
                DropdownMenuItem(
                  value: item,
                  child: Text('${item.icon} ${context.tr(item.name)}'),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 20),
          _kindCard(
            context,
            kind: _PostKind.text,
            icon: Icons.notes_outlined,
            title: 'Standard post',
            subtitle: 'Share an update, idea, or local news.',
          ),
          _kindCard(
            context,
            kind: _PostKind.media,
            icon: Icons.photo_library_outlined,
            title: 'Photos or video',
            subtitle: 'Tell your story with up to 10 media files.',
          ),
          _kindCard(
            context,
            kind: _PostKind.poll,
            icon: Icons.poll_outlined,
            title: 'Poll',
            subtitle: 'Ask a question and let members vote.',
          ),
          if (_canPublishTodayMenu)
            _kindCard(
              context,
              kind: _PostKind.todayMenu,
              icon: Icons.restaurant_menu,
              title: "Today's menu",
              subtitle: 'Publish dishes, prices and availability for today.',
            ),
          if (_hasBusinessService(BusinessService.retail))
            _kindCard(
              context,
              kind: _PostKind.retailOffer,
              icon: Icons.local_offer_outlined,
              title: 'Product or offer',
              subtitle: 'Share a product, price and availability.',
            ),
          if (_hasBusinessService(BusinessService.transport))
            _kindCard(
              context,
              kind: _PostKind.transportTrip,
              icon: Icons.directions_bus_outlined,
              title: 'Trip availability',
              subtitle: 'Share a route, departure time and available seats.',
            ),
          if (_hasBusinessService(BusinessService.realEstate))
            _kindCard(
              context,
              kind: _PostKind.realEstate,
              icon: Icons.apartment_outlined,
              title: 'Property listing',
              subtitle: 'Publish a property for rent or sale.',
            ),
          if (_hasBusinessService(BusinessService.professionalServices))
            _kindCard(
              context,
              kind: _PostKind.professionalService,
              icon: Icons.business_center_outlined,
              title: 'Professional service',
              subtitle: 'Describe a service, area and starting price.',
            ),
        ],
      );

  Widget _kindCard(
    BuildContext context, {
    required _PostKind kind,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _kind == kind;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .55)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('post-kind-${kind.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() {
            _kind = kind;
            _hasPoll = kind == _PostKind.poll;
          }),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(title),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(context.tr(subtitle)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? colors.primary : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contentStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Create your content'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(context.tr('Write your post and add anything it needs.')),
      const SizedBox(height: 18),
      if (_kind == _PostKind.todayMenu)
        _todayMenuEditor(context)
      else if (_isStructuredBusinessPost)
        _businessFeatureEditor(context)
      else
        PostRichTextEditor(controller: _textController),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _saving ? null : _chooseMentions,
        icon: const Icon(Icons.alternate_email),
        label: Text(
          _mentionedUserIds.isEmpty
              ? context.tr('Tag members')
              : context.tr('{count} tagged', {
                  'count': '${_mentionedUserIds.length}',
                }),
        ),
      ),
      if (_kind == _PostKind.media ||
          _isStructuredBusinessPost ||
          _attachments.isNotEmpty) ...[
        const SizedBox(height: 22),
        _mediaEditor(context),
      ] else ...[
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => setState(() => _kind = _PostKind.media),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(context.tr('Add photos or video')),
        ),
      ],
      if (_hasPoll) ...[const SizedBox(height: 22), _pollEditor(context)],
    ],
  );

  Widget _optionsStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Post options'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(context.tr('Review how this post will be published.')),
      const SizedBox(height: 20),
      _postingDestination(context),
      if (_canPublishAnonymously) ...[
        const SizedBox(height: 16),
        _anonymousOption(context),
      ],
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(context.tr('Category')),
          subtitle: Text(
            _category == null
                ? context.tr('Not selected')
                : '${_category!.icon} ${context.tr(_category!.name)}',
          ),
          trailing: TextButton(
            onPressed: () => setState(() => _step = 0),
            child: Text(context.tr('Change')),
          ),
        ),
      ),
    ],
  );

  Widget _previewStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Preview'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(context.tr('Review everything before publishing.')),
      const SizedBox(height: 18),
      FutureBuilder<WicchuProfile>(
        future: _postingAuthor,
        builder: (context, snapshot) {
          final author = _publishAnonymously
              ? context.tr(
                  _canPublishAsAdmin ? 'Community Admin' : 'Anonymous Member',
                )
              : snapshot.data?.name ?? context.tr('You');
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${widget.community.name} · ${_category == null ? '' : context.tr(_category!.name)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 28),
                  Text(_effectiveText),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 180,
                      child: PostMediaGallery(
                        media: _attachments.map((item) => item.media).toList(),
                      ),
                    ),
                  ],
                  if (_hasPoll) ...[
                    const SizedBox(height: 14),
                    for (final option in _pollControllers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(option.text.trim()),
                        ),
                      ),
                  ],
                  if (_effectiveText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _copyDescription(_effectiveText),
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(context.tr('Copy description')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _postingDestination(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_2_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${context.tr('Posting to')} '),
                TextSpan(
                  text: widget.community.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _anonymousOption(BuildContext context) => Card(
    child: SwitchListTile.adaptive(
      value: _publishAnonymously,
      onChanged: _saving
          ? null
          : (value) => setState(() => _publishAnonymously = value),
      secondary: const Icon(Icons.person_off_outlined),
      title: Text(context.tr('Publish anonymously')),
      subtitle: Text(
        context.tr(
          _canPublishAsAdmin
              ? '“Community Admin” will appear instead of your name. Your identity remains available for security and auditing.'
              : 'Anonymous posts are always reviewed by a community administrator before publication. Administrators can still identify you for safety.',
        ),
      ),
    ),
  );

  Widget _todayMenuEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr("Today's menu"),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(context.tr('This menu automatically expires tonight.')),
              const SizedBox(height: 16),
              for (final (index, dish) in _menuDishes.indexed) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: ValueKey('menu-dish-$index'),
                        controller: dish.name,
                        maxLength: 120,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: context.tr('Dish'),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: dish.price,
                        maxLength: 30,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: context.tr('Price'),
                          hintText: r'$5.00',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Remove'),
                      onPressed: _menuDishes.length == 1
                          ? null
                          : () => setState(() {
                              final removed = _menuDishes.removeAt(index);
                              removed.dispose();
                            }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: dish.available,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(context.tr('Available today')),
                  onChanged: (value) =>
                      setState(() => dish.available = value ?? true),
                ),
                if (index < _menuDishes.length - 1) const Divider(),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _menuDishes.length >= 30
                    ? null
                    : () => setState(() => _menuDishes.add(_MenuDishDraft())),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Add dish')),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        context.tr('Available options'),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in BusinessFulfillmentOption.values)
            FilterChip(
              label: Text(context.tr(option.label)),
              avatar: Icon(switch (option) {
                BusinessFulfillmentOption.delivery =>
                  Icons.delivery_dining_outlined,
                BusinessFulfillmentOption.pickup => Icons.shopping_bag_outlined,
                BusinessFulfillmentOption.eatIn => Icons.restaurant_outlined,
              }, size: 18),
              selected: _menuFulfillment.contains(option),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _menuFulfillment.add(option);
                } else {
                  _menuFulfillment.remove(option);
                }
              }),
            ),
        ],
      ),
    ],
  );

  Widget _businessFeatureEditor(BuildContext context) {
    final title = switch (_kind) {
      _PostKind.retailOffer => 'Product or offer',
      _PostKind.transportTrip => 'Trip availability',
      _PostKind.realEstate => 'Property listing',
      _ => 'Professional service',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(title),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_kind != _PostKind.transportTrip)
              TextField(
                controller: _featureTitle,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr(switch (_kind) {
                    _PostKind.retailOffer => 'Product or offer name',
                    _PostKind.realEstate => 'Property title',
                    _ => 'Service name',
                  }),
                ),
              ),
            if (_kind == _PostKind.transportTrip) ...[
              TextField(
                controller: _featureFrom,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('Departure location'),
                  prefixIcon: const Icon(Icons.trip_origin),
                ),
              ),
              TextField(
                controller: _featureTo,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('Destination'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(context.tr('Departure time')),
                subtitle: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatFullDate(_featureDepartureAt),
                ),
                trailing: Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(_featureDepartureAt),
                  ),
                ),
                onTap: _pickDeparture,
              ),
              TextField(
                controller: _featureNumber,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('Available seats'),
                  prefixIcon: const Icon(Icons.event_seat_outlined),
                ),
              ),
            ],
            if (_kind == _PostKind.realEstate) ...[
              DropdownButtonFormField<String>(
                initialValue: _propertyListingType,
                decoration: InputDecoration(
                  labelText: context.tr('Listing type'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'rent',
                    child: Text(context.tr('For rent')),
                  ),
                  DropdownMenuItem(
                    value: 'sale',
                    child: Text(context.tr('For sale')),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _propertyListingType = value ?? 'rent'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _featureNumber,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('Bedrooms'),
                  prefixIcon: const Icon(Icons.bed_outlined),
                ),
              ),
              TextField(
                controller: _featureLocation,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('Property location'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
            ],
            if (_kind == _PostKind.professionalService)
              TextField(
                controller: _featureServiceArea,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('Service area'),
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
              ),
            TextField(
              controller: _featurePrice,
              maxLength: 30,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.tr(
                  _kind == _PostKind.professionalService
                      ? 'Starting price (optional)'
                      : 'Price',
                ),
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            if (_kind != _PostKind.transportTrip)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _featureAvailable,
                title: Text(context.tr('Currently available')),
                onChanged: (value) => setState(() => _featureAvailable = value),
              ),
            if (_kind == _PostKind.retailOffer) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('Delivery and pickup'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in const [
                    BusinessFulfillmentOption.delivery,
                    BusinessFulfillmentOption.pickup,
                  ])
                    FilterChip(
                      label: Text(context.tr(option.label)),
                      selected: _menuFulfillment.contains(option),
                      onSelected: (selected) => setState(() {
                        selected
                            ? _menuFulfillment.add(option)
                            : _menuFulfillment.remove(option);
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _featureDepartureAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_featureDepartureAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _featureDepartureAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).subtract(const Duration(milliseconds: 1));
  }

  String _todayMenuPostText() {
    final dishes = _menuDishes
        .where((dish) => dish.name.text.trim().isNotEmpty)
        .map((dish) {
          final price = dish.price.text.trim();
          final unavailable = dish.available ? '' : ' · Unavailable';
          return '• ${dish.name.text.trim()}${price.isEmpty ? '' : ' — $price'}$unavailable';
        })
        .join('\n');
    if (dishes.isEmpty) return '';
    final options = _menuFulfillment.map((option) => option.label).join(' · ');
    return [
      "🍴 Today's menu · ${widget.community.name}",
      dishes,
      if (options.isNotEmpty) options,
    ].join('\n\n');
  }

  String _retailOfferPostText() => [
    '🏷️ ${_featureTitle.text.trim()}',
    if (_featurePrice.text.trim().isNotEmpty) _featurePrice.text.trim(),
    _featureAvailable ? 'Available' : 'Unavailable',
  ].join('\n');

  String _transportTripPostText() => [
    '🚌 ${_featureFrom.text.trim()} → ${_featureTo.text.trim()}',
    '${_featureDepartureAt.toLocal()}',
    '${_featureNumber.text.trim()} seats available',
    if (_featurePrice.text.trim().isNotEmpty) _featurePrice.text.trim(),
  ].join('\n');

  String _realEstatePostText() => [
    '🏠 ${_featureTitle.text.trim()}',
    _propertyListingType == 'rent' ? 'For rent' : 'For sale',
    _featurePrice.text.trim(),
    '${_featureNumber.text.trim()} bedrooms · ${_featureLocation.text.trim()}',
    _featureAvailable ? 'Available' : 'Unavailable',
  ].join('\n');

  String _professionalServicePostText() => [
    '🧰 ${_featureTitle.text.trim()}',
    'Service area: ${_featureServiceArea.text.trim()}',
    if (_featurePrice.text.trim().isNotEmpty)
      'Starting at ${_featurePrice.text.trim()}',
    _featureAvailable ? 'Available' : 'Unavailable',
  ].join('\n');

  BusinessPostFeature? _buildBusinessFeature() => switch (_kind) {
    _PostKind.retailOffer => BusinessPostFeature(
      type: BusinessPostFeatureType.retailOffer,
      title: _featureTitle.text.trim(),
      price: _featurePrice.text.trim(),
      available: _featureAvailable,
      fulfillmentOptions: _menuFulfillment
          .where(
            (option) =>
                option == BusinessFulfillmentOption.delivery ||
                option == BusinessFulfillmentOption.pickup,
          )
          .toList(growable: false),
    ),
    _PostKind.transportTrip => BusinessPostFeature(
      type: BusinessPostFeatureType.transportTrip,
      price: _featurePrice.text.trim(),
      routeFrom: _featureFrom.text.trim(),
      routeTo: _featureTo.text.trim(),
      departureAt: _featureDepartureAt,
      seatsAvailable: int.tryParse(_featureNumber.text.trim()),
    ),
    _PostKind.realEstate => BusinessPostFeature(
      type: BusinessPostFeatureType.realEstateListing,
      title: _featureTitle.text.trim(),
      price: _featurePrice.text.trim(),
      available: _featureAvailable,
      listingType: _propertyListingType,
      bedrooms: int.tryParse(_featureNumber.text.trim()),
      location: _featureLocation.text.trim(),
    ),
    _PostKind.professionalService => BusinessPostFeature(
      type: BusinessPostFeatureType.professionalService,
      title: _featureTitle.text.trim(),
      price: _featurePrice.text.trim(),
      available: _featureAvailable,
      serviceArea: _featureServiceArea.text.trim(),
    ),
    _ => null,
  };

  Widget _mediaEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.tr('Media'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text('${_attachments.length}/10'),
        ],
      ),
      const SizedBox(height: 10),
      if (_uploading) const LinearProgressIndicator(),
      SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachments.length + (_attachments.length < 10 ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == _attachments.length) {
              return SizedBox(
                width: 108,
                child: OutlinedButton.icon(
                  onPressed: _saving || _uploading ? null : _chooseMedia,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(context.tr('Add')),
                ),
              );
            }
            final attachment = _attachments[index];
            return SizedBox(
              width: 108,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        attachment.bytes != null &&
                            attachment.media.type == 'image'
                        ? Image.memory(attachment.bytes!, fit: BoxFit.cover)
                        : PostMediaGallery(media: [attachment.media]),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton.filled(
                      tooltip: context.tr('Remove'),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _attachments.removeAt(index)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _pollEditor(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Poll options'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      for (final (index, controller) in _pollControllers.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: controller,
            onChanged: (_) => _refreshValidity(),
            enabled: !_pollLocked,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: context.tr('Option {number}', {
                'number': '${index + 1}',
              }),
              counterText: '',
              suffixIcon: !_pollLocked && _pollControllers.length > 2
                  ? IconButton(
                      onPressed: () => setState(() {
                        _pollControllers.removeAt(index).dispose();
                      }),
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
        ),
      if (!_pollLocked && _pollControllers.length < 10)
        TextButton.icon(
          onPressed: () =>
              setState(() => _pollControllers.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: Text(context.tr('Add option')),
        ),
    ],
  );

  bool get _canContinue => switch (_step) {
    0 => _category != null,
    1 =>
      _effectiveText.isNotEmpty &&
          !_textController.exceedsCharacterLimit &&
          !_uploading &&
          _validTodayMenu &&
          _validBusinessFeature &&
          (_kind != _PostKind.media || _attachments.isNotEmpty) &&
          (!_hasPoll ||
              (_pollControllers.length >= 2 &&
                  _pollControllers.every(
                    (controller) => controller.text.trim().isNotEmpty,
                  ) &&
                  _pollControllers
                          .map((item) => item.text.trim())
                          .toSet()
                          .length ==
                      _pollControllers.length)),
    2 => true,
    _ => _canSubmit,
  };

  Widget _stepNavigation(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
    child: Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => setState(() => _step--),
              child: Text(context.tr('Back')),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: _step == 0 ? 1 : 2,
          child: FilledButton.icon(
            key: ValueKey(_step == 3 ? 'publish-post' : 'next-post-step'),
            onPressed: !_canContinue || _saving
                ? null
                : _step == 3
                ? _publish
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => _step++);
                  },
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_step == 3 ? Icons.publish : Icons.arrow_forward),
            label: Text(
              context.tr(
                _step == 3 ? (_isEditing ? 'Save changes' : 'Publish') : 'Next',
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _successScreen(BuildContext context, CommunityPost post) {
    final pending = post.status == PostStatus.pendingApproval;
    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: Text(context.tr(pending ? 'Submitted' : 'Published')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(
                  pending ? Icons.hourglass_top : Icons.check,
                  size: 54,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(
                  pending ? 'Post submitted for approval' : 'Post published',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  pending
                      ? 'A community moderator will review it before publication.'
                      : 'Your post is live and can now be shared.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, post),
                  child: Text(context.tr('View post')),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _resetComposer,
                  child: Text(context.tr('Create another post')),
                ),
              ),
              if (!pending) ...[
                const SizedBox(height: 28),
                Text(
                  context.tr('Get more reach'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (post.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _copyDescription(post.text.trim()),
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(context.tr('Copy description')),
                      ),
                    ),
                  ),
                _shareAction(
                  context,
                  post,
                  icon: Icons.auto_awesome_outlined,
                  label: 'Instagram Story',
                  destination: PostShareDestination.instagramStory,
                ),
                _shareAction(
                  context,
                  post,
                  icon: Icons.photo_outlined,
                  label: 'Instagram Post',
                  destination: PostShareDestination.instagramFeed,
                ),
                _shareAction(
                  context,
                  post,
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  destination: PostShareDestination.whatsapp,
                ),
                _shareAction(
                  context,
                  post,
                  icon: Icons.facebook_outlined,
                  label: 'Facebook',
                  destination: PostShareDestination.facebook,
                ),
                _shareAction(
                  context,
                  post,
                  icon: Icons.link,
                  label: 'Copy link',
                  destination: PostShareDestination.copyLink,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareAction(
    BuildContext context,
    CommunityPost post, {
    required IconData icon,
    required String label,
    required PostShareDestination destination,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            sharePostTo(context, widget.repository, post, destination),
        icon: Icon(icon),
        label: Text(context.tr(label)),
      ),
    ),
  );

  Future<void> _copyDescription(String description) async {
    await Clipboard.setData(ClipboardData(text: description));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('Description copied'))));
  }

  void _resetComposer() {
    _textController.clear();
    _attachments.clear();
    _mentionedUserIds.clear();
    _publishAnonymously = false;
    _hasPoll = false;
    _kind = _PostKind.text;
    for (final dish in _menuDishes) {
      dish.dispose();
    }
    _menuDishes
      ..clear()
      ..add(_MenuDishDraft());
    _menuFulfillment.clear();
    _featureTitle.clear();
    _featurePrice.clear();
    _featureFrom.clear();
    _featureTo.clear();
    _featureNumber.clear();
    _featureLocation.clear();
    _featureServiceArea.clear();
    _featureAvailable = true;
    _propertyListingType = 'rent';
    _featureDepartureAt = DateTime.now().add(const Duration(hours: 1));
    for (final controller in _pollControllers) {
      controller.dispose();
    }
    _pollControllers
      ..clear()
      ..addAll([TextEditingController(), TextEditingController()]);
    setState(() {
      _publishedPost = null;
      _step = 0;
    });
  }

  // Retained temporarily while the structured editor replaces the old editor.
  // ignore: unused_element
  Future<void> _chooseMedia() async {
    if (_uploading || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final video = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(context.tr('Photo')),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(context.tr('Video')),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (video != null && mounted) await _pickMedia(video: video);
  }

  Future<void> _publish() async {
    if (_saving || !widget.community.canPublish) return;
    if (_textController.exceedsCharacterLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Use at most {count} characters.', {
              'count': '${PostTextController.maxCharacters}',
            }),
          ),
        ),
      );
      return;
    }
    final text = _effectiveText;
    final pollOptions = _hasPoll
        ? _pollControllers.map((controller) => controller.text.trim()).toList()
        : const <String>[];
    if (_category == null || text.isEmpty || _uploading || !_validTodayMenu) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Choose a category and add text.'))),
      );
      return;
    }
    if (_hasPoll &&
        (pollOptions.any((option) => option.isEmpty) ||
            pollOptions.toSet().length != pollOptions.length)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Add at least two unique poll options.')),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final currentSpace = await widget.repository.getCommunity(
        widget.community.id,
      );
      if (!currentSpace.canPublish) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'You do not have permission to publish in this space.',
                ),
              ),
            ),
          );
        }
        return;
      }
      final input = CreatePostInput(
        categoryId: _category!.id,
        text: text,
        media: _attachments.map((item) => item.media).toList(),
        pollOptions: pollOptions,
        mentionedUserIds: _mentionedUserIds.toList(growable: false),
        anonymousAsAdmin: _publishAnonymously && _canPublishAsAdmin,
        anonymousAsMember: _publishAnonymously && !_canPublishAsAdmin,
        todayMenu: _kind == _PostKind.todayMenu
            ? TodayMenu(
                dishes: [
                  for (final dish in _menuDishes)
                    TodayMenuDish(
                      name: dish.name.text.trim(),
                      price: dish.price.text.trim(),
                      available: dish.available,
                    ),
                ],
                fulfillmentOptions: _menuFulfillment.toList(growable: false),
                expiresAt: _endOfToday(),
              )
            : null,
        businessFeature: _buildBusinessFeature(),
      );
      final post = _isEditing
          ? await widget.repository.updatePost(widget.existingPost!.id, input)
          : await widget.repository.createPost(widget.community.id, input);
      if (!mounted) return;
      if (_isEditing) {
        Navigator.pop(context, post);
      } else {
        setState(() {
          _saving = false;
          _publishedPost = post;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _pickMedia({required bool video}) async {
    if (_uploading || _saving) return;
    if (_attachments.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('A post supports up to 10 files.'))),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      final file = video
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 90,
              requestFullMetadata: false,
            );
      if (file == null || !mounted) return;
      if (await file.length() > 25 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('The file must be under 25 MB.')),
            ),
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final media = await widget.repository.uploadPostMedia(
        bytes: bytes,
        filename: file.name,
        mimeType: file.mimeType ?? _mimeTypeFor(file.name, video: video),
      );
      if (mounted) {
        setState(() => _attachments.add(_PostAttachment(media, bytes)));
      }
    } catch (error) {
      if (mounted) {
        final denied =
            error is PlatformException &&
            {
              'photo_access_denied',
              'photo_access_restricted',
            }.contains(error.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              denied
                  ? context.tr(
                      'Allow photo access for Wicchu in iPhone Settings, then try again.',
                    )
                  : context.trError(error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeTypeFor(String filename, {required bool video}) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'gif' => 'image/gif',
      'mov' => 'video/quicktime',
      'mp4' => 'video/mp4',
      _ => video ? 'video/mp4' : 'image/jpeg',
    };
  }
}

class _PostAttachment {
  const _PostAttachment(this.media, this.bytes);

  final PostMedia media;
  final Uint8List? bytes;
}

class _MenuDishDraft {
  _MenuDishDraft({String name = '', String price = '', this.available = true})
    : name = TextEditingController(text: name),
      price = TextEditingController(text: price);

  final TextEditingController name;
  final TextEditingController price;
  bool available;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

enum _PostKind {
  text,
  media,
  poll,
  todayMenu,
  retailOffer,
  transportTrip,
  realEstate,
  professionalService,
}

Future<CommunityPost?> openEditPost(
  BuildContext context,
  CommunityRepository repository,
  CommunityPost post,
) async {
  try {
    final communities = await repository.listJoinedCommunities();
    final community = communities
        .where((item) => item.id == post.communityId)
        .firstOrNull;
    if (community == null) throw StateError('Community not found');
    final categories = await repository.listCategories(community.id);
    if (!context.mounted) return null;
    return await openPostComposer(
      context,
      community: community,
      repository: repository,
      categories: categories,
      existingPost: post,
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
    return null;
  }
}
