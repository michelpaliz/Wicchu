import 'package:flutter/material.dart';

import '../../theme/wicchu_theme.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.category,
    required this.icon,
    required this.community,
    required this.author,
    required this.time,
    required this.text,
    this.price,
    this.likes = 0,
    this.comments = 0,
    this.showImage = false,
    this.onTap,
  });

  final String category;
  final String icon;
  final String community;
  final String author;
  final String time;
  final String text;
  final String? price;
  final int likes;
  final int comments;
  final bool showImage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = categoryColor(category, context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$icon ${category.toUpperCase()} · $community',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$author · $time',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Text(text, style: Theme.of(context).textTheme.titleMedium),
              if (price != null) ...[
                const SizedBox(height: 6),
                Text(
                  price!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              if (showImage) ...[
                const SizedBox(height: 14),
                Container(
                  height: 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Icon(Icons.image_outlined, size: 54, color: accent),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _PostAction(icon: Icons.favorite_border, value: '$likes'),
                  const SizedBox(width: 22),
                  _PostAction(
                    icon: Icons.chat_bubble_outline,
                    value: '$comments',
                  ),
                  const Spacer(),
                  const Icon(Icons.ios_share_outlined, size: 21),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 20), const SizedBox(width: 6), Text(value)],
  );
}
