import 'package:share_plus/share_plus.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';

Future<void> sharePost(
  CommunityRepository repository,
  CommunityPost post, {
  String? communityName,
}) async {
  await repository.recordPostShare(post.id).catchError((_) {});
  final excerpt = post.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final shortened = excerpt.length > 160
      ? '${excerpt.substring(0, 157)}…'
      : excerpt;
  await SharePlus.instance.share(
    ShareParams(
      subject: communityName == null
          ? 'A post on Wicchu'
          : '$communityName on Wicchu',
      text:
          '$shortened\n\nRead the full post on Wicchu:\n'
          'https://hexora.dev/wicchu/posts/${post.id}',
    ),
  );
}
