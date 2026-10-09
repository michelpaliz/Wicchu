import 'package:wicchu/theme/wicchu_icons.dart';
import '../../widgets/explore_result_card.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ExploreResultCard(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: UserAvatar(
                    userId: person.id,
                    name: person.name,
                    imageUrl: person.avatarUrl,
                    radius: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (person.userName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${person.userName.replaceFirst(RegExp(r'^@'), '')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (person.sharedCommunityCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              WicchuIcons.users,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                context.trCount(
                                  person.sharedCommunityCount,
                                  singular: '{count} shared community',
                                  plural: '{count} shared communities',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
