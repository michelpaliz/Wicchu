import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/widgets/wicchu_network_image.dart';

void main() {
  test('different media blobs and image versions have distinct cache keys', () {
    expect(
      stableImageCacheKey('https://example.com/media?blobName=old.jpg'),
      isNot(stableImageCacheKey('https://example.com/media?blobName=new.jpg')),
    );
    expect(
      stableImageCacheKey('https://example.com/image.jpg?v=1'),
      isNot(stableImageCacheKey('https://example.com/image.jpg?v=2')),
    );
  });

  test('signed image URLs share a stable cache key', () {
    const first = 'https://storage.example.com/image.jpg?sig=one&se=1';
    const second = 'https://storage.example.com/image.jpg?sig=two&se=2';
    expect(stableImageCacheKey(first), stableImageCacheKey(second));
    expect(
      stableImageCacheKey(first, cacheKey: 'community-posts/image.jpg'),
      'community-posts/image.jpg',
    );
  });

  test('post media uses its thumbnail only for previews', () {
    const media = PostMedia(
      url: 'https://storage.example.com/original.jpg',
      type: 'image',
      blobName: 'community-posts/original.jpg',
      thumbnailUrl: 'https://storage.example.com/thumbnail.webp',
      thumbnailBlobName: 'community-thumbnails/thumbnail.webp',
    );
    expect(media.previewUrl, media.thumbnailUrl);
    expect(media.previewCacheKey, media.thumbnailBlobName);
    expect(media.url, contains('original.jpg'));
  });
}
