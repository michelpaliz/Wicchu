import 'package:flutter/material.dart';

import '../../domain/community_models.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.community, this.radius = 24});

  final Community community;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    backgroundImage: community.imageUrl == null
        ? null
        : NetworkImage(community.imageUrl!),
    child: community.imageUrl == null
        ? Icon(Icons.groups_outlined, size: radius)
        : null,
  );
}
