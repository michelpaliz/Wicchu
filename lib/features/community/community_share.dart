import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';

Future<void> shareCommunity(
  BuildContext context,
  Community community,
) => SharePlus.instance.share(
  ShareParams(
    subject: context.tr('Join {community} on Wicchu', {
      'community': community.name,
    }),
    text:
        '${context.tr('Join {community} on Wicchu:', {'community': community.name})} '
        'https://hexora.dev/wicchu/communities/${community.id}',
  ),
);
