import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../../config/wicchu_urls.dart';

Future<void> shareCommunity(
  BuildContext context,
  Community community,
) => SharePlus.instance.share(
  ShareParams(
    subject: context.tr(
      community.isPublicProfile
          ? 'Follow {community} on Wicchu'
          : 'Join {community} on Wicchu',
      {'community': community.name},
    ),
    text:
        '${context.tr(community.isPublicProfile ? 'Follow {community} on Wicchu:' : 'Join {community} on Wicchu:', {'community': community.name})} '
        '${WicchuUrls.community(community.id, community.slug)}',
  ),
);
