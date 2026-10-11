import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../widgets/wicchu_network_image.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    super.key,
    required this.community,
    this.radius = 24,
    this.square = false,
  });

  final Community community;
  final double radius;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Icon(
      community.isPublicProfile &&
              community.profileCategory == ProfileCategory.localBusiness
          ? WicchuIcons.storefront
          : community.isPublicProfile
          ? WicchuIcons.userCircle
          : WicchuIcons.usersThree,
      size: radius,
      color: colors.primary,
    );
    final url = community.imageUrl?.trim();
    if (square) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: radius * 2,
          height: radius * 2,
          color: colors.primaryContainer,
          child: url == null || url.isEmpty
              ? Center(child: placeholder)
              : WicchuNetworkImage(
                  url: url,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  decodeWidth:
                      (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                  errorBuilder: (_) => Center(child: placeholder),
                ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: url == null || url.isEmpty
          ? placeholder
          : ClipOval(
              child: WicchuNetworkImage(
                url: url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                decodeWidth:
                    (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                errorBuilder: (_) => Center(child: placeholder),
              ),
            ),
    );
  }
}
