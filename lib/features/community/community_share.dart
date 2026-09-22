import 'package:share_plus/share_plus.dart';

import '../../domain/community_models.dart';

Future<void> shareCommunity(Community community) => SharePlus.instance.share(
  ShareParams(
    subject: 'Join ${community.name} on Wicchu',
    text:
        'Join ${community.name} on Wicchu: '
        'https://hexora.dev/wicchu/communities/${community.id}',
  ),
);
