import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';

class SpaceRoleIcon extends StatelessWidget {
  const SpaceRoleIcon({super.key, required this.space});

  final Community space;

  @override
  Widget build(BuildContext context) {
    final label = context.tr(switch (space.myRole) {
      CommunityRole.owner => 'Owner',
      CommunityRole.admin => 'Administrator',
      CommunityRole.moderator => 'Moderator',
      _ => space.isPublicProfile ? 'Following' : 'Member',
    });
    final icon = switch (space.myRole) {
      CommunityRole.owner => WicchuIcons.shield,
      CommunityRole.admin => WicchuIcons.shieldCheck,
      CommunityRole.moderator => WicchuIcons.shieldCheck,
      _ => WicchuIcons.userCheck,
    };
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.tap,
      child: SizedBox.square(
        dimension: 40,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
        ),
      ),
    );
  }
}
