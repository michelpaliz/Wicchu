import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/community_share.dart';

class CreateCommunityPage extends StatefulWidget {
  const CreateCommunityPage({super.key, required this.repository});

  final CommunityRepository repository;

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
      body: FutureBuilder<List<Town>>(
        future: widget.repository.listTowns(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stepper(
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
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text('Finding your current town…'),
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
                                _locationError ??
                                    'Wicchu needs your location to find your town and nearby communities.',
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
                        _locationVerified
                            ? 'Update my location'
                            : 'Use my current location',
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
                      title: Text(
                        context.tr('Approve posts before publishing'),
                      ),
                      subtitle: Text(
                        context.tr('You can change this later by category.'),
                      ),
                      value: _approvalRequired,
                      onChanged: (value) =>
                          setState(() => _approvalRequired = value),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_nameController.text.trim()),
                      subtitle: Text(
                        '${_town?.name ?? ''} · ${context.tr('{count} categories', {'count': '${_selectedCategories.length}'})}\n'
                        '${context.tr('Public community · You will be the owner')}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
        const SnackBar(
          content: Text('Confirm your current location to continue.'),
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
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
            onPressed: () => shareCommunity(community),
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

  Future<void> _detectLocation() async {
    setState(() {
      _detectingLocation = true;
      _locationError = null;
      _locationVerified = false;
      _town = null;
    });
    try {
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
