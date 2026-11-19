import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/widgets/youtube_post_embed.dart';
import 'package:wicchu/features/community/post_rich_text_editor.dart';
import 'package:wicchu/widgets/facebook_post_embed.dart';

void main() {
  test('extracts supported YouTube URL formats and validates IDs', () {
    final links = extractYoutubePostLinks('''
https://www.youtube.com/watch?v=dQw4w9WgXcQ
https://youtu.be/9bZkp7q19f0?t=12
https://youtube.com/shorts/aqz-KE-bpKQ
https://www.youtube.com/live/jNQXAC9IVRw
''');

    expect(links.map((link) => link.videoId), [
      'dQw4w9WgXcQ',
      '9bZkp7q19f0',
      'aqz-KE-bpKQ',
      'jNQXAC9IVRw',
    ]);
  });

  test('ignores malformed, unsupported, and duplicate links', () {
    final links = extractYoutubePostLinks('''
https://youtube.com/watch?v=too-short
https://youtube.com/watch?v=dQw4w9WgXcQ
https://youtube.com/watch?v=dQw4w9WgXcQ
https://youtube.com/channel/dQw4w9WgXcQ
''');

    expect(links, hasLength(1));
    expect(links.single.videoId, 'dQw4w9WgXcQ');
  });

  test('normalizes pasted iframe markup to its original YouTube URL', () {
    const iframe =
        '<iframe src="https://www.youtube.com/embed/lHJe_FKy5-Y?si=abc">player</iframe>';
    expect(
      normalizeYoutubeIframeText('Watch this $iframe'),
      'Watch this https://www.youtube.com/embed/lHJe_FKy5-Y?si=abc',
    );
    expect(extractYoutubePostLinks(iframe).single.videoId, 'lHJe_FKy5-Y');
  });

  test('extracts supported public Facebook video links', () {
    final links = extractFacebookPostLinks('''
https://www.facebook.com/watch/?v=123456789
https://www.facebook.com/example/videos/987654321
https://www.facebook.com/reel/246813579
https://fb.watch/AbCdEf/
''');
    expect(links, hasLength(4));
  });
}
