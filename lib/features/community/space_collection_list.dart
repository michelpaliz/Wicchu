import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import 'community_avatar.dart';
import 'space_role_icon.dart';

/// Compact joined/managed spaces with shared type and audience terminology.
class SpaceCollectionList extends StatefulWidget {
  const SpaceCollectionList({
    super.key,
    required this.spaces,
    required this.onOpen,
    required this.onRefresh,
    this.statusBuilder,
  });

  final List<Community> spaces;
  final ValueChanged<Community> onOpen;
  final Future<void> Function() onRefresh;
  final Widget Function(Community)? statusBuilder;

  @override
  State<SpaceCollectionList> createState() => _SpaceCollectionListState();
}

class _SpaceCollectionListState extends State<SpaceCollectionList> {
  int _filter = 0;

  Widget _metadata(
    BuildContext context,
    IconData icon,
    String label, {
    CommunityVisibility? visibility,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      if (visibility != null) ...[
        const SizedBox(width: 6),
        Tooltip(
          message: context.tr(
            visibility == CommunityVisibility.public ? 'Public' : 'Private',
          ),
          triggerMode: TooltipTriggerMode.tap,
          child: Icon(
            visibility == CommunityVisibility.public
                ? WicchuIcons.globe
                : WicchuIcons.lockKey,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.tr(
              visibility == CommunityVisibility.public ? 'Public' : 'Private',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visible = widget.spaces
        .where(
          (space) =>
              _filter == 0 ||
              (_filter == 1 ? !space.isPublicProfile : space.isPublicProfile),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final entry in const [
                'All',
                'Communities',
                'Public profiles',
              ].asMap().entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(context.tr(entry.value)),
                    selected: _filter == entry.key,
                    showCheckmark: true,
                    checkmarkColor: colors.onPrimary,
                    selectedColor: colors.primary,
                    backgroundColor: colors.surfaceContainerLow,
                    side: BorderSide(
                      color: _filter == entry.key
                          ? colors.primary
                          : colors.outlineVariant.withValues(alpha: .5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: _filter == entry.key
                          ? colors.onPrimary
                          : colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _filter = entry.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.trCount(
                      visible.length,
                      singular: '{count} space',
                      plural: '{count} spaces',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      context.tr('No spaces in this section yet.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final space in visible)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: colors.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .4),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => widget.onOpen(space),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CommunityAvatar(community: space, radius: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    space.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 2,
                                    children: [
                                      _metadata(
                                        context,
                                        WicchuIcons.mapPin,
                                        space.town.name,
                                      ),
                                      _metadata(
                                        context,
                                        WicchuIcons.users,
                                        context.trCount(
                                          space.memberCount,
                                          singular: space.isPublicProfile
                                              ? '{count} follower'
                                              : '{count} member',
                                          plural: space.isPublicProfile
                                              ? '{count} followers'
                                              : '{count} members',
                                        ),
                                        visibility: space.isPublicProfile
                                            ? null
                                            : space.visibility,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (widget.statusBuilder != null) ...[
                                    const SizedBox(height: 4),
                                    widget.statusBuilder!(space),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            SpaceRoleIcon(space: space),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
