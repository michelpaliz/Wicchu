import 'package:flutter/material.dart';

import '../../domain/community_models.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.community, this.radius = 24});

  final Community community;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Icons.holiday_village_outlined,
      size: radius,
      color: colors.primary,
    );
    final url = community.imageUrl?.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: url == null || url.isEmpty
          ? placeholder
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: placeholder),
              ),
            ),
    );
  }
}
