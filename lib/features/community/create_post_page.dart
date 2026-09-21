import 'package:flutter/material.dart';

import '../../domain/community_models.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.community,
    this.initialCategory,
    this.categories = const [],
  });

  final Community community;
  final CommunityCategory? initialCategory;
  final List<CommunityCategory> categories;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  CommunityCategory? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? widget.categories.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.categories.isEmpty && widget.initialCategory != null
        ? [widget.initialCategory!]
        : widget.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Create post')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.community.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<CommunityCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final item in categories)
                DropdownMenuItem(
                  value: item,
                  child: Text('${item.icon} ${item.name}'),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 20),
          const TextField(
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'What would you like to share?',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Photo'),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Video'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Publish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
