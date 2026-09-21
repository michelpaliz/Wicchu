import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import 'create_post_page.dart';
import 'post_card.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({
    super.key,
    required this.community,
    required this.category,
  });

  final Community community;
  final CommunityCategory category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CreatePostPage(community: community, initialCategory: category),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(category.name == 'Marketplace' ? 'Sell / Post' : 'Post'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Text(community.name, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'latest', label: Text('Latest')),
              ButtonSegment(value: 'popular', label: Text('Popular')),
            ],
            selected: const {'latest'},
            onSelectionChanged: (_) {},
          ),
          const SizedBox(height: 18),
          PostCard(
            category: category.name,
            icon: category.icon,
            community: community.name,
            author: 'Carlos M.',
            time: '43 min',
            text: category.name == 'Marketplace'
                ? 'Mountain bike for sale'
                : 'Latest update from our community',
            price: category.name == 'Marketplace' ? r'$180' : null,
            likes: 7,
            comments: 12,
            showImage: category.name == 'Marketplace',
          ),
        ],
      ),
    );
  }
}
