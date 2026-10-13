import '../../widgets/wicchu_list_tile.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../community/user_avatar.dart';

/// Compact profile result; keeps avatar loading and profile actions with callers.
class ExplorePersonCard extends StatelessWidget {
  const ExplorePersonCard({
    super.key,
    required this.person,
    required this.onTap,
  });

  final PeopleSearchResult person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (person.sharedCommunityCount > 0)
        context.trCount(
          person.sharedCommunityCount,
          singular: '{count} shared community',
          plural: '{count} shared communities',
        ),
      if (person.distanceKm != null)
        context.tr('{distance} km away', {
          'distance': person.distanceKm! < 10
              ? person.distanceKm!.toStringAsFixed(1)
              : person.distanceKm!.round().toString(),
        }),
    ];
    return WicchuListTile(
      variant: WicchuListVariant.person,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: UserAvatar(
        userId: person.id,
        name: person.name,
        imageUrl: person.avatarUrl,
        radius: 22,
      ),
      title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (person.userName.isNotEmpty)
            Text(
              '@${person.userName.replaceFirst(RegExp(r'^@'), '')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (metadata.isNotEmpty)
            Text(
              metadata.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
