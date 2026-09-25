import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/community_input_limits.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/community_share.dart';
import 'rule_management_page.dart';

class CreateCommunityPage extends StatefulWidget {
  const CreateCommunityPage({
    super.key,
    required this.repository,
    this.locateCurrentTown,
  });

  final CommunityRepository repository;
  final Future<Town> Function()? locateCurrentTown;

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
  final _descriptionController = TextEditingController();
  final _selectedCategories = <String>{..._defaults};
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
  bool _approvalRequired = false;
  bool _detectingLocation = false;
  bool _locationVerified = false;
  String? _locationError;

  @override
  void dispose() {
    _scroll.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
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
    final scheme = Theme.of(context).colorScheme;
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
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(context.tr('Create community')),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Step {current} of {total}', {
                        'current': '${_step + 1}',
                        'total': '4',
                      }),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_step + 1) / 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
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
                          style: Theme.of(context).textTheme.titleLarge!,
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
                    onPressed: _saving || _detectingLocation ? null : _continue,
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
                        : Text(
                            context.tr(
                              _step == 3 ? 'Create community' : 'Continue',
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

  List<Step> _steps(BuildContext context) => [
    Step(
      title: Text(context.tr('Basics')),
      isActive: _step >= 0,
      content: Form(
        key: _basicsForm,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              maxLength: CommunityInputLimits.name,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Add a community name.')
                  : null,
              decoration: InputDecoration(
                labelText: context.tr('Community name'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLength: CommunityInputLimits.description,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr('Short description'),
                helperText: context.tr('Optional'),
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
          if (_detectingLocation)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(context.tr('Finding your current town…')),
                    ),
                  ],
                ),
              ),
            )
          else if (_locationVerified && _town != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(_town!.name),
                subtitle: Text(_town!.countryCode),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.location_off_outlined, size: 38),
                    const SizedBox(height: 8),
                    Text(
                      _locationError == null
                          ? context.tr(
                              'Wicchu needs your location to find your town and nearby communities.',
                            )
                          : context.tr(_locationError!),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (_locationSettings)
            TextButton(
              onPressed: () => _serviceSettings
                  ? Geolocator.openLocationSettings()
                  : Geolocator.openAppSettings(),
              child: Text(context.tr('Open settings')),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _detectingLocation ? null : _detectLocation,
            icon: const Icon(Icons.my_location),
            label: Text(
              context.tr(
                _locationVerified
                    ? 'Update my location'
                    : 'Use my current location',
              ),
            ),
          ),
        ],
      ),
    ),
    Step(
      title: Text(context.tr('Categories')),
      isActive: _step >= 2,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              'Choose the topics for your community. You can change them later.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in _defaults)
                FilterChip(
                  label: Text(context.tr(category)),
                  selected: _selectedCategories.contains(category),
                  onSelected: (selected) => setState(() {
                    _dirty = true;
                    _categoryError = null;
                    selected
                        ? _selectedCategories.add(category)
                        : _selectedCategories.remove(category);
                  }),
                ),
            ],
          ),
          if (_categoryError != null)
            Text(
              _categoryError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    Step(
      title: Text(context.tr('Rules and review')),
      isActive: _step >= 3,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Rules are optional. You can add or edit them later.'),
          ),
          const SizedBox(height: 12),
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
                icon: const Icon(Icons.close),
              ),
              onTap: () => _editDraftRule(index),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _draftRules.length >= 25
                  ? null
                  : () => _editDraftRule(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add rule')),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Review your community'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text.trim(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_descriptionController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_descriptionController.text.trim()),
                  ],
                  const SizedBox(height: 12),
                  Text(_town?.name ?? ''),
                  Text(context.tr('Public community · You will be the owner')),
                  const SizedBox(height: 12),
                  Text(_selectedCategories.map(context.tr).join(' · ')),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ];

  Future<void> _continue() async {
    if (_saving || _detectingLocation) return;
    if (_step == 0 && !(_basicsForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    if (_step == 1 && (!_locationVerified || _town == null)) {
      setState(
        () => _locationError = 'Confirm your current location to continue.',
      );
      return;
    }
    if (_step == 2 && _selectedCategories.isEmpty) {
      setState(
        () => _categoryError = context.tr('Choose at least one category.'),
      );
      return;
    }
    if (_step < 3) {
      final nextStep = _step + 1;
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
          description: _descriptionController.text.trim(),
          town: _town!,
          visibility: CommunityVisibility.public,
          categoryNames: _selectedCategories.toList(),
          approvalRequired: _approvalRequired,
          rules: _draftRules,
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
        icon: const Icon(Icons.celebration_outlined, size: 42),
        title: Text(dialogContext.tr('Your community is ready!')),
        content: Text(
          dialogContext.tr(
            'Invite your first members and start the conversation.',
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => shareCommunity(dialogContext, community),
            icon: const Icon(Icons.ios_share_outlined),
            label: Text(dialogContext.tr('Share invitation')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Enter community')),
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

  Future<void> _detectLocation() async {
    setState(() {
      _detectingLocation = true;
      _locationError = null;
      _locationSettings = false;
      _serviceSettings = false;
      _locationVerified = false;
      _town = null;
    });
    try {
      if (widget.locateCurrentTown != null) {
        final town = await widget.locateCurrentTown!();
        if (!mounted) return;
        setState(() {
          _town = town;
          _locationVerified = true;
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
          'Location permission is required to create a community.',
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
        _locationVerified = true;
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
