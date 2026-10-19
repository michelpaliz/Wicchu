import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/community_input_limits.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/community_share.dart';
import 'rule_management_page.dart';
import '../../widgets/creation_step_progress.dart';
import 'place_search_page.dart';
import '../../services/place_search_service.dart';

class CreateCommunityPage extends StatefulWidget {
  const CreateCommunityPage({
    super.key,
    required this.repository,
    this.locateCurrentTown,
    this.searchPlaces,
    this.initialType = CommunityType.community,
  });

  final CommunityRepository repository;
  final CommunityType initialType;
  final Future<Town> Function()? locateCurrentTown;
  final Future<List<PlaceResult>> Function(String query, String language)?
  searchPlaces;

  @override
  State<CreateCommunityPage> createState() => _CreateCommunityPageState();
}

class _CreateCommunityPageState extends State<CreateCommunityPage> {
  static const _defaults = [
    'General',
    'News',
    'Marketplace',
    'Jobs',
    'Events',
    'Local Businesses',
    'Politics',
    'Housing',
    'Sports',
    'Lost & Found',
  ];

  final _nameController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _customCategoryController = TextEditingController();
  static const _businessSuggestions = [
    'Products',
    'Offers',
    'News',
    'Events',
    'Tips',
    'Questions',
    'Tutorials',
    'Testimonials',
  ];
  final _businessCategories = <String>{};
  final _customBusinessCategories = <String>{};
  final _businessCategoryController = TextEditingController();
  String? _businessCategoryError;
  bool get _isLocalBusiness =>
      _type == CommunityType.publicProfile &&
      _profileCategory == ProfileCategory.localBusiness;
  List<String> get _creationCategories => !_isLocalBusiness
      ? _categoryKeys.keys
            .where(_selectedCategories.contains)
            .toList(growable: false)
      : _isLocalBusiness && _businessCategories.isNotEmpty
      ? _businessCategories.toList()
      : ['Posts'];

  final _selectedCategories = <String>{};
  final _categoryKeys = <String, String?>{};
  final _draftRules = <CommunityRule>[];
  final _basicsForm = GlobalKey<FormState>();
  final _scroll = ScrollController();
  bool _allowExit = false;
  bool _dirty = false;
  bool _locationSettings = false;
  bool _serviceSettings = false;
  String? _categoryError;
  int _step = 0;
  Town? _town;
  bool _saving = false;
  bool _loadingCategories = false;
  bool _suggestionsLoaded = false;
  bool _approvalRequired = false;
  late CommunityType _type = widget.initialType;
  ProfileCategory? _profileCategory;
  bool _detectingLocation = false;
  String? _selectedLocationLabel;
  String? _locationError;
  CommunityScope _scope = CommunityScope.local;

  @override
  void dispose() {
    _businessCategoryController.dispose();
    _scroll.dispose();
    _nameController.dispose();
    _shortDescriptionController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_step > 0) {
      setState(() => _step--);
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }
    if (_dirty ||
        _nameController.text.isNotEmpty ||
        _shortDescriptionController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('Discard community draft?')),
          content: Text(context.tr('Your changes will not be saved.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Keep editing')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Discard')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps(context);
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.tr('Back'),
            onPressed: _saving ? null : _back,
            icon: const Icon(WicchuIcons.arrowLeft),
          ),
          title: Text(context.tr('Create a space')),
        ),
        body: SafeArea(
          child: Column(
            children: [
              CreationStepProgress(step: _step),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: AbsorbPointer(
                    absorbing: _saving,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(fontWeight: FontWeight.w700),
                          child: steps[_step].title,
                        ),
                        const SizedBox(height: 20),
                        steps[_step].content,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed:
                        _saving ||
                            _detectingLocation ||
                            (_step == 0 && _nameController.text.trim().isEmpty)
                        ? null
                        : _continue,
                    child: _saving
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(context.tr('Creating…')),
                            ],
                          )
                        : _isLocalBusiness && _step == 2
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(context.tr('Continue')),
                              const SizedBox(width: 12),
                              const Icon(WicchuIcons.arrowRight, size: 20),
                            ],
                          )
                        : Text(
                            context.tr(
                              _step == 3 ? 'Create space' : 'Continue',
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeCard(
    CommunityType type,
    IconData icon,
    String title,
    String description,
  ) {
    final selected = _type == type;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .06)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? colors.primary
                : colors.onSurface.withValues(alpha: .15),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('space-type-${type.name}'),
          onTap: () => setState(() {
            _type = type;
            if (type == CommunityType.publicProfile) {
              _scope = CommunityScope.local;
            }
            _dirty = true;
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 30,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const Spacer(),
                    Icon(
                      selected ? WicchuIcons.radioButton : WicchuIcons.circle,
                      color: selected ? colors.primary : colors.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr(title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(description),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Step> _steps(BuildContext context) => [
    Step(
      title: Text(context.tr('What would you like to create?')),
      isActive: _step >= 0,
      content: Form(
        key: _basicsForm,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.tr(
                  'Choose the type of space that best fits your needs.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _typeCard(
                    CommunityType.community,
                    WicchuIcons.usersThree,
                    'Community',
                    'Members join and participate together.',
                  ),
                  _typeCard(
                    CommunityType.publicProfile,
                    WicchuIcons.user,
                    'Public profile',
                    'People follow a person, business, creator or organization.',
                  ),
                ];
                if (constraints.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                  return Column(
                    children: [cards[0], const SizedBox(height: 12), cards[1]],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.tr(
                  _type == CommunityType.community
                      ? 'Community details'
                      : 'Profile details',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            if (_type == CommunityType.publicProfile) ...[
              DropdownButtonFormField<ProfileCategory>(
                initialValue: _profileCategory,
                decoration: InputDecoration(
                  labelText: context.tr('Profile category'),
                ),
                items: [
                  for (final category in ProfileCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(context.tr(category.label)),
                    ),
                ],
                validator: (value) => value == null
                    ? context.tr('Choose a profile category.')
                    : null,
                onChanged: (value) => setState(() {
                  _profileCategory = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameController,
              onChanged: (_) => setState(() => _dirty = true),
              maxLength: CommunityInputLimits.name,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr(
                      _type == CommunityType.publicProfile
                          ? 'Add a page name.'
                          : 'Add a community name.',
                    )
                  : null,
              decoration: InputDecoration(
                labelText: context.tr(
                  _type == CommunityType.publicProfile
                      ? 'Page name'
                      : 'Community name',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: InputDecoration(
                labelText: context.tr('Subject or purpose'),
                hintText: context.tr(
                  'For example: football, gardening or technology',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shortDescriptionController,
              onChanged: (_) => setState(() => _dirty = true),
              maxLength: CommunityInputLimits.shortDescription,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: context.tr('A quick summary shown on your profile.'),
                labelText: context.tr('Short description'),
                helperText: context.tr('Optional'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              onChanged: (_) => setState(() => _dirty = true),
              maxLength: CommunityInputLimits.description,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              minLines: 3,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: context.tr(
                  'Tell people more about your community or page…',
                ),
                labelText: context.tr('About'),
                helperText: context.tr('Optional'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    WicchuIcons.lightbulb,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Tip'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                            _type == CommunityType.community
                                ? 'A clear name and description help people find and join your community.'
                                : 'A clear name and description help people find and follow your profile.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    Step(
      title: Text(context.tr('Location')),
      isActive: _step >= 1,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_type == CommunityType.community) ...[
            Text(
              context.tr('Community reach'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SegmentedButton<CommunityScope>(
              segments: [
                ButtonSegment(
                  value: CommunityScope.local,
                  icon: const Icon(WicchuIcons.mapPin),
                  label: Text(context.tr('Location-based')),
                ),
                ButtonSegment(
                  value: CommunityScope.global,
                  icon: const Icon(WicchuIcons.globe),
                  label: Text(context.tr('Anywhere')),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (value) => setState(() {
                _scope = value.first;
                _locationError = null;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                _scope == CommunityScope.global
                    ? 'Open to people everywhere. No location is required.'
                    : 'Connected to a specific city, town, or area.',
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (_scope == CommunityScope.local ||
              _type == CommunityType.publicProfile) ...[
            Text(
              context.tr('Where is this space?'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Search for a location or use your current position.'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _detectingLocation ? null : _searchLocation,
              icon: const Icon(WicchuIcons.magnifyingGlass),
              label: Text(context.tr('Search city or place')),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Search by city, town or area'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _detectingLocation ? null : _detectLocation,
              icon: const Icon(WicchuIcons.crosshair),
              label: Text(context.tr('Use my current location')),
            ),
            if (_detectingLocation) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_locationError != null) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(_locationError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_locationSettings)
              TextButton(
                onPressed: () => _serviceSettings
                    ? Geolocator.openLocationSettings()
                    : Geolocator.openAppSettings(),
                child: Text(context.tr('Open settings')),
              ),
            if (_town != null) ...[
              const SizedBox(height: 18),
              Text(
                context.tr('Selected location'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(WicchuIcons.mapPin),
                  title: Text(
                    _selectedLocationLabel ??
                        '${_town!.name}, ${_town!.countryCode}',
                  ),
                  trailing: Icon(
                    WicchuIcons.checkCircleFill,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
          if (_scope == CommunityScope.global &&
              _type == CommunityType.community)
            Card(
              child: ListTile(
                leading: const Icon(WicchuIcons.globe),
                title: Text(context.tr('Open to people everywhere')),
                subtitle: Text(
                  context.tr(
                    'This community will appear in Explore and search, but not Nearby.',
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    Step(
      title: Text(context.tr('Organize your space')),
      isActive: _step >= 2,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              _isLocalBusiness
                  ? 'Choose optional categories for your business posts, or add your own. You can change them later.'
                  : 'Choose suggested topics for your space, or add your own. Category suggestions are free.',
            ),
          ),
          if (!_isLocalBusiness) ...[
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Suggestions are generated once for each new space. You can customize them before creating it.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          if (_isLocalBusiness)
            _businessCategoryPicker()
          else ...[
            if (_loadingCategories) const LinearProgressIndicator(),
            if (!_loadingCategories) _communityCategoryOrganizer(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customCategoryController,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: context.tr('Add a category'),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addCustomCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _addCustomCategory,
                  icon: const Icon(WicchuIcons.plus),
                  tooltip: context.tr('Add category'),
                ),
              ],
            ),
          ],
          if (!_isLocalBusiness && _categoryError != null)
            Text(
              _categoryError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    Step(
      title: Text(context.tr('Review and create')),
      isActive: _step >= 3,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(
              'Check that everything is correct before creating your space.',
            ),
          ),
          const SizedBox(height: 20),
          _reviewSummary(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _editStep(0),
            icon: const Icon(WicchuIcons.pencilSimple),
            label: Text(context.tr('Edit information')),
          ),
          if (_type == CommunityType.community) ...[
            const SizedBox(height: 20),
            Text(
              context.tr('Rules are optional. You can add or edit them later.'),
            ),
          ],
          if (_type == CommunityType.community)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Approve posts before publishing')),
              subtitle: Text(
                context.tr('You can change this later by category.'),
              ),
              value: _approvalRequired,
              onChanged: (value) => setState(() {
                _dirty = true;
                _approvalRequired = value;
              }),
            ),
          if (_type == CommunityType.community)
            for (final (index, rule) in _draftRules.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(rule.title),
                subtitle: Text(
                  rule.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: context.tr('Delete rule'),
                  onPressed: () => setState(() => _draftRules.removeAt(index)),
                  icon: const Icon(WicchuIcons.x),
                ),
                onTap: () => _editDraftRule(index),
              ),
          if (_type == CommunityType.community)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _draftRules.length >= 25
                    ? null
                    : () => _editDraftRule(),
                icon: const Icon(WicchuIcons.plus),
                label: Text(context.tr('Add rule')),
              ),
            ),
          const SizedBox(height: 20),
          _creationConfirmation(),
        ],
      ),
    ),
  ];

  void _editStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _reviewSummary() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget icon(IconData value) => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(value, color: colors.primary, size: 24),
    );
    Widget row(
      IconData symbol,
      String title,
      Widget value, {
      VoidCallback? onTap,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: icon(symbol),
      title: Text(
        context.tr(title),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: value),
      trailing: onTap == null
          ? null
          : const Icon(WicchuIcons.caretRight, size: 20),
      onTap: _saving ? null : onTap,
    );
    final divider = Divider(
      height: 1,
      indent: 74,
      endIndent: 16,
      color: colors.onSurface.withValues(alpha: .08),
    );
    return Card(
      key: const ValueKey('space-review-summary'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.onSurface.withValues(alpha: .10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon(
                  _isLocalBusiness
                      ? WicchuIcons.storefront
                      : _type == CommunityType.community
                      ? WicchuIcons.usersThree
                      : WicchuIcons.userCircle,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.trim(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          context.tr(
                            _type == CommunityType.publicProfile
                                ? 'Public page'
                                : 'Public community',
                          ),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                      if (_shortDescriptionController.text
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _shortDescriptionController.text.trim(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (_descriptionController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          context.tr('About'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _descriptionController.text.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          divider,
          row(
            WicchuIcons.mapPin,
            'Location',
            Text(
              _selectedLocationLabel ??
                  '${_town?.name ?? ''}, ${_town?.countryCode ?? ''}',
            ),
            onTap: () => _editStep(1),
          ),
          divider,
          row(
            WicchuIcons.tag,
            'Categories',
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in _creationCategories)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      context.tr(category),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            onTap: _type == CommunityType.community || _isLocalBusiness
                ? () => _editStep(2)
                : null,
          ),
          divider,
          row(WicchuIcons.user, 'Owner', Text(context.tr('You'))),
        ],
      ),
    );
  }

  Widget _creationConfirmation() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(WicchuIcons.checkCircleFill, color: colors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(
                'By creating this space, you confirm that the information provided is correct.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessCategoryPicker() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtleBorder = colors.onSurface.withValues(alpha: .14);
    Widget chip(String name) {
      final selected = _businessCategories.contains(name);
      final icon = switch (name) {
        'Products' => WicchuIcons.tag,
        'Offers' => WicchuIcons.percent,
        'News' => WicchuIcons.newspaper,
        'Events' => WicchuIcons.calendarBlank,
        'Tips' => WicchuIcons.lightbulb,
        'Questions' => WicchuIcons.question,
        'Tutorials' => WicchuIcons.playCircle,
        'Testimonials' => WicchuIcons.chatCircle,
        _ => WicchuIcons.tag,
      };
      return FilterChip(
        avatar: Icon(
          icon,
          size: 21,
          color: selected ? colors.primary : colors.onSurface,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(name),
              style: TextStyle(
                color: selected ? colors.primary : colors.onSurface,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(
                WicchuIcons.checkCircleFill,
                color: colors.primary,
                size: 20,
              ),
            ],
          ],
        ),
        showCheckmark: false,
        selected: selected,
        selectedColor: colors.primary.withValues(alpha: .09),
        backgroundColor: colors.surface,
        side: BorderSide(color: selected ? colors.primary : subtleBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        onSelected: (value) => setState(() {
          _dirty = true;
          value
              ? _businessCategories.add(name)
              : _businessCategories.remove(name);
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          context.tr('Suggested for your type of space'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('Select one or more.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _businessSuggestions.map(chip).toList(),
        ),
        const SizedBox(height: 16),
        Divider(color: subtleBorder),
        const SizedBox(height: 16),
        Text(
          context.tr('Add your own category'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('Enter a custom category.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('business-category-name'),
          controller: _businessCategoryController,
          maxLength: CommunityInputLimits.name,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addBusinessCategory(),
          onChanged: (_) {
            if (_businessCategoryError != null) {
              setState(() => _businessCategoryError = null);
            }
          },
          decoration: InputDecoration(
            hintText: context.tr('e.g. Food, Pets, Technology'),
            hintStyle: TextStyle(
              color: colors.onSurface.withValues(alpha: .45),
            ),
            prefixIconColor: colors.onSurfaceVariant,
            prefixIcon: IconButton(
              tooltip: context.tr('Add category'),
              onPressed: _addBusinessCategory,
              icon: const Icon(WicchuIcons.plus),
            ),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: subtleBorder),
            ),
            errorText: _businessCategoryError,
          ),
        ),
        if (_customBusinessCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _customBusinessCategories.map(chip).toList(),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(WicchuIcons.info, color: colors.onSurfaceVariant, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr(
                    'Without categories, your posts will appear under Posts.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addBusinessCategory() {
    final name = _businessCategoryController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final existing = [
      'Posts',
      ..._businessSuggestions,
      ..._customBusinessCategories,
    ];
    if (name.isEmpty) {
      setState(
        () => _businessCategoryError = context.tr('Enter a category name.'),
      );
      return;
    }
    final duplicate = existing
        .where(
          (item) =>
              item.toLowerCase() == name.toLowerCase() ||
              context.tr(item).toLowerCase() == name.toLowerCase(),
        )
        .firstOrNull;
    if (duplicate != null) {
      setState(
        () => _businessCategoryError = context.tr(
          'This category already exists.',
        ),
      );
      return;
    }
    setState(() {
      _customBusinessCategories.add(name);
      _businessCategories.add(name);
      _businessCategoryController.clear();
      _businessCategoryError = null;
      _dirty = true;
    });
  }

  Future<void> _continue() async {
    if (_saving || _detectingLocation) return;
    if (_step == 0 && !(_basicsForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    if (_step == 1 && _scope == CommunityScope.local && _town == null) {
      setState(() => _locationError = 'Choose a location to continue.');
      return;
    }
    if (_step == 2 && !_isLocalBusiness && _selectedCategories.isEmpty) {
      setState(
        () => _categoryError = context.tr('Choose at least one category.'),
      );
      return;
    }
    if (_step < 3) {
      final nextStep = _step + 1;
      if (nextStep == 2 && !_isLocalBusiness) {
        await _loadCategorySuggestions();
        if (!mounted) return;
      }
      setState(() => _step = nextStep);
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }
    setState(() => _saving = true);
    late final Community community;
    try {
      community = await widget.repository.createCommunity(
        CreateCommunityInput(
          name: _nameController.text.trim(),
          shortDescription: _shortDescriptionController.text.trim(),
          description: _descriptionController.text.trim(),
          subject: _subjectController.text.trim(),
          town: _scope == CommunityScope.local ? _town : null,
          scope: _scope,
          visibility: CommunityVisibility.public,
          categoryNames: _creationCategories,
          categories: [
            for (final name in _creationCategories)
              CategorySuggestion(key: _categoryKeys[name], name: name),
          ],
          approvalRequired: _approvalRequired,
          rules: _draftRules,
          type: _type,
          profileCategory: _type == CommunityType.publicProfile
              ? _profileCategory
              : null,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(WicchuIcons.confetti, size: 42),
        title: Text(
          dialogContext.tr(
            _type == CommunityType.publicProfile
                ? 'Your business or public page is ready!'
                : 'Your community is ready!',
          ),
        ),
        content: Text(
          dialogContext.tr(
            _type == CommunityType.publicProfile &&
                    community.profileCategory != _profileCategory
                ? 'Your profile was created, but its category could not be saved. You can set it later in settings.'
                : _type == CommunityType.publicProfile
                ? 'Share your profile and publish your first update.'
                : 'Invite your first members and start the conversation.',
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => shareCommunity(dialogContext, community),
            icon: const Icon(WicchuIcons.export),
            label: Text(
              dialogContext.tr(
                _type == CommunityType.publicProfile
                    ? 'Share profile'
                    : 'Share invitation',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              dialogContext.tr(
                _type == CommunityType.publicProfile
                    ? 'Open profile'
                    : 'Enter community',
              ),
            ),
          ),
        ],
      ),
    );
    if (mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, community);
      });
    }
  }

  Future<void> _loadCategorySuggestions() async {
    if (_suggestionsLoaded || _loadingCategories) return;
    setState(() => _loadingCategories = true);
    try {
      final repository = widget.repository;
      final result = repository is CategorySuggestionRepository
          ? await (repository as CategorySuggestionRepository)
                .getCategorySuggestions(
                  spaceType: _type,
                  subject: _subjectController.text.trim().isEmpty
                      ? '${_nameController.text} ${_descriptionController.text}'
                      : _subjectController.text.trim(),
                  language: AppLanguageScope.of(context).languageCode,
                )
          : CategorySuggestions(
              template: 'default',
              categories: [
                for (final name in _defaults)
                  CategorySuggestion(key: null, name: name),
              ],
            );
      if (!mounted) return;
      setState(() {
        _categoryKeys
          ..clear()
          ..addEntries(
            result.categories.map((item) => MapEntry(item.name, item.key)),
          );
        _selectedCategories
          ..clear()
          ..addAll(result.categories.take(5).map((item) => item.name));
        _suggestionsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoryKeys
          ..clear()
          ..addEntries(_defaults.map((name) => MapEntry(name, null)));
        _selectedCategories
          ..clear()
          ..addAll(_defaults.take(5));
        _suggestionsLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _addCustomCategory() {
    final name = _customCategoryController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final duplicate = _categoryKeys.keys.any(
      (item) => item.toLowerCase() == name.toLowerCase(),
    );
    if (name.isEmpty ||
        name.length > 80 ||
        duplicate ||
        _categoryKeys.length >= 20) {
      return;
    }
    setState(() {
      _categoryKeys[name] = null;
      _selectedCategories.add(name);
      _customCategoryController.clear();
      _categoryError = null;
      _dirty = true;
    });
  }

  Widget _communityCategoryOrganizer() {
    final categories = _categoryKeys.keys.toList(growable: false);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: categories.length,
      onReorderItem: _reorderCategory,
      itemBuilder: (context, index) {
        final name = categories[index];
        final recommended = _categoryKeys[name] != null;
        return Card(
          key: ValueKey('creation-category-$name'),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 8, right: 4),
            leading: Checkbox(
              value: _selectedCategories.contains(name),
              onChanged: (selected) => setState(() {
                _dirty = true;
                _categoryError = null;
                selected == true
                    ? _selectedCategories.add(name)
                    : _selectedCategories.remove(name);
              }),
            ),
            title: Text(context.tr(name)),
            subtitle: Text(context.tr(recommended ? 'Recommended' : 'Custom')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _renameCategory(name),
                  icon: const Icon(WicchuIcons.pencilSimple),
                  tooltip: context.tr('Rename category'),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      WicchuIcons.dotsThreeVertical,
                      semanticLabel: context.tr('Reorder category'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _reorderCategory(int oldIndex, int newIndex) {
    final entries = _categoryKeys.entries.toList();
    final moved = entries.removeAt(oldIndex);
    entries.insert(newIndex, moved);
    setState(() {
      _categoryKeys
        ..clear()
        ..addEntries(entries);
      _dirty = true;
    });
  }

  Future<void> _renameCategory(String currentName) async {
    final controller = TextEditingController(text: currentName);
    String? error;
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Rename category')),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.tr('Category name'),
              errorText: error,
            ),
            onSubmitted: (value) {
              final validation = _categoryRenameError(currentName, value);
              if (validation == null) {
                Navigator.pop(
                  dialogContext,
                  value.trim().replaceAll(RegExp(r'\s+'), ' '),
                );
              } else {
                setDialogState(() => error = validation);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final validation = _categoryRenameError(
                  currentName,
                  controller.text,
                );
                if (validation == null) {
                  Navigator.pop(
                    dialogContext,
                    controller.text.trim().replaceAll(RegExp(r'\s+'), ' '),
                  );
                } else {
                  setDialogState(() => error = validation);
                }
              },
              child: Text(context.tr('Save')),
            ),
          ],
        ),
      ),
    );
    if (!mounted || renamed == null || renamed == currentName) return;
    final entries = _categoryKeys.entries
        .map(
          (entry) => MapEntry(
            entry.key == currentName ? renamed : entry.key,
            entry.value,
          ),
        )
        .toList();
    setState(() {
      final wasSelected = _selectedCategories.remove(currentName);
      _categoryKeys
        ..clear()
        ..addEntries(entries);
      if (wasSelected) _selectedCategories.add(renamed);
      _dirty = true;
    });
  }

  String? _categoryRenameError(String currentName, String value) {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return context.tr('Enter a category name.');
    if (name.length > 80) return context.tr('Category name is too long.');
    if (_categoryKeys.keys.any(
      (item) => item != currentName && item.toLowerCase() == name.toLowerCase(),
    )) {
      return context.tr('This category already exists.');
    }
    return null;
  }

  Future<void> _editDraftRule([int? index]) async {
    final existing = index == null ? null : _draftRules[index];
    (String, String)? result;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityRuleEditorPage(
          rule: existing,
          communityName: _nameController.text.trim(),
          onSave: (title, description) async {
            result = (title, description);
          },
        ),
      ),
    );
    if (result == null || !mounted) return;
    final saved = result!;
    setState(() {
      _dirty = true;
      final rule = CommunityRule(
        title: saved.$1,
        description: saved.$2,
        position: index ?? _draftRules.length,
      );
      if (index == null) {
        _draftRules.add(rule);
      } else {
        _draftRules[index] = rule;
      }
    });
  }

  Future<void> _searchLocation() async {
    final place = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceSearchPage(
          search: widget.searchPlaces ?? PlaceSearchService().search,
        ),
      ),
    );
    if (!mounted || place == null) return;
    setState(() {
      _detectingLocation = true;
      _locationError = null;
      _locationSettings = false;
    });
    try {
      final town = await widget.repository.locateTown(
        latitude: place.latitude,
        longitude: place.longitude,
      );
      if (!mounted) return;
      setState(() {
        _town = town;
        _selectedLocationLabel =
            town.name.toLowerCase() == place.name.toLowerCase()
            ? place.label
            : '${town.name}, ${town.countryCode}';
        _dirty = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError =
              'Unable to select this location. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _detectLocation() async {
    setState(() {
      _detectingLocation = true;
      _locationError = null;
      _locationSettings = false;
      _serviceSettings = false;
    });
    try {
      if (widget.locateCurrentTown != null) {
        final town = await widget.locateCurrentTown!();
        if (!mounted) return;
        setState(() {
          _town = town;
          _selectedLocationLabel = null;
          _dirty = true;
        });
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationSettings = true;
        _serviceSettings = true;
        throw Exception('Turn on location services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _locationSettings = true;
        throw Exception(
          'Location permission is blocked. Enable it in your device settings.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. You can search for a location instead.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      final town = await widget.repository.locateTown(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _town = town;
        _selectedLocationLabel = null;
        _dirty = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _locationError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }
}
