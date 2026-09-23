import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/community_share.dart';

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
  int _step = 0;
  Town? _town;
  bool _saving = false;
  bool _approvalRequired = false;
  bool _detectingLocation = false;
  bool _locationVerified = false;
  String? _locationError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Create community'))),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _continue,
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              FilledButton(
                onPressed: _saving ? null : details.onStepContinue,
                child: Text(
                  context.tr(_step == 3 ? 'Create community' : 'Continue'),
                ),
              ),
              if (_step > 0)
                TextButton(
                  onPressed: _saving ? null : details.onStepCancel,
                  child: Text(context.tr('Back')),
                ),
            ],
          ),
        ),
        steps: [
          Step(
            title: Text(context.tr('Basics')),
            isActive: _step >= 0,
            content: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('Community name'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr('Short description'),
                  ),
                ),
              ],
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
                            child: Text(
                              context.tr('Finding your current town…'),
                            ),
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
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
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
            content: Wrap(
              spacing: 8,
              children: [
                for (final category in _defaults)
                  FilterChip(
                    label: Text(context.tr(category)),
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _selectedCategories.add(category)
                          : _selectedCategories.remove(category);
                    }),
                  ),
              ],
            ),
          ),
          Step(
            title: Text(context.tr('Rules')),
            isActive: _step >= 3,
            content: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('Approve posts before publishing')),
                  subtitle: Text(
                    context.tr('You can change this later by category.'),
                  ),
                  value: _approvalRequired,
                  onChanged: (value) =>
                      setState(() => _approvalRequired = value),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_nameController.text.trim()),
                  subtitle: Text(
                    '${_town?.name ?? ''} · ${context.trCount(_selectedCategories.length, singular: '{count} category', plural: '{count} categories')}\n'
                    '${context.tr('Public community · You will be the owner')}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    if (_step == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Add a community name.'))),
      );
      return;
    }
    if (_step == 1 && (!_locationVerified || _town == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Confirm your current location to continue.'),
          ),
        ),
      );
      return;
    }
    if (_step == 2 && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Choose at least one category.'))),
      );
      return;
    }
    if (_step < 3) {
      final nextStep = _step + 1;
      setState(() => _step = nextStep);
      if (nextStep == 1 && !_locationVerified) await _detectLocation();
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
    if (mounted) Navigator.pop(context, community);
  }

  Future<void> _editDraftRule([int? index]) async {
    final existing = index == null ? null : _draftRules[index];
    final title = TextEditingController(text: existing?.title);
    final description = TextEditingController(text: existing?.description);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr(existing == null ? 'Add rule' : 'Edit rule'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: dialogContext.tr('Rule title'),
                ),
              ),
              TextField(
                controller: description,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: dialogContext.tr('Description'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final normalizedTitle = title.text.trim();
              final normalizedDescription = description.text.trim();
              if (normalizedTitle.isEmpty || normalizedDescription.isEmpty) {
                return;
              }
              Navigator.pop(
                dialogContext,
                (normalizedTitle, normalizedDescription),
              );
            },
            child: Text(dialogContext.tr('Save')),
          ),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    if (result == null || !mounted) return;
    setState(() {
      final rule = CommunityRule(
        title: result.$1,
        description: result.$2,
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
        throw Exception('Turn on location services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
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
