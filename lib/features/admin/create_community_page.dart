import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

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
  late final Future<List<Town>> _towns;

  @override
  void initState() {
    super.initState();
    _towns = widget.repository.listTowns();
  }

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
        future: _towns,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(context.trError(snapshot.error!)));
          }
          final towns = snapshot.data ?? const <Town>[];
          if (towns.isEmpty) {
            return Center(child: Text(context.tr('No towns found')));
          }
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
                content: DropdownButtonFormField<Town>(
                  initialValue: _town,
                  decoration: InputDecoration(labelText: context.tr('Town')),
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
                        '${_town?.name ?? ''} · ${context.trCount(_selectedCategories.length, singular: '{count} category', plural: '{count} categories')}\n'
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

  Future<void> _continue(List<Town> towns) async {
    if (_step == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Add a community name.'))),
      );
      return;
    }
    if (_step == 1 && _town == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Choose a town.'))));
      return;
    }
    if (_step == 2 && _selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Choose at least one category.'))),
      );
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
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
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Enter community')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, community);
  }
}
