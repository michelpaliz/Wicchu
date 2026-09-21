import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create community')),
      body: FutureBuilder<List<Town>>(
        future: widget.repository.listTowns(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final towns = snapshot.data!;
          _town ??= towns.firstOrNull;
          return Stepper(
            currentStep: _step,
            onStepContinue: () => _continue(towns),
            onStepCancel: _step == 0 ? null : () => setState(() => _step--),
            controlsBuilder: (context, details) => Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : details.onStepContinue,
                    child: Text(_step == 3 ? 'Create community' : 'Continue'),
                  ),
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : details.onStepCancel,
                      child: const Text('Back'),
                    ),
                ],
              ),
            ),
            steps: [
              Step(
                title: const Text('Basics'),
                isActive: _step >= 0,
                content: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Community name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Short description',
                      ),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Location'),
                isActive: _step >= 1,
                content: DropdownButtonFormField<Town>(
                  initialValue: _town,
                  decoration: const InputDecoration(labelText: 'Town'),
                  items: [
                    for (final town in towns)
                      DropdownMenuItem(
                        value: town,
                        child: Text('${town.name}, ${town.countryCode}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _town = value),
                ),
              ),
              Step(
                title: const Text('Categories'),
                isActive: _step >= 2,
                content: Wrap(
                  spacing: 8,
                  children: [
                    for (final category in _defaults)
                      FilterChip(
                        label: Text(category),
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
                title: const Text('Rules'),
                isActive: _step >= 3,
                content: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Approve posts before publishing'),
                      subtitle: const Text(
                        'You can change this later by category.',
                      ),
                      value: _approvalRequired,
                      onChanged: (value) =>
                          setState(() => _approvalRequired = value),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_nameController.text.trim()),
                      subtitle: Text(
                        '${_town?.name ?? ''} · ${_selectedCategories.length} categories\n'
                        'Public community · You will be the owner',
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

  Future<void> _continue(List<Town> towns) async {
    if (_step == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a community name.')));
      return;
    }
    if (_step == 1 && _town == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a town.')));
      return;
    }
    if (_step == 2 && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one category.')),
      );
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    final community = await widget.repository.createCommunity(
      CreateCommunityInput(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        town: _town!,
        visibility: CommunityVisibility.public,
        categoryNames: _selectedCategories.toList(),
      ),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.celebration_outlined, size: 42),
        title: const Text('Your community is ready!'),
        content: const Text(
          'Invite your first members and start the conversation.',
        ),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Share invitation'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Enter community'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, community);
  }
}
