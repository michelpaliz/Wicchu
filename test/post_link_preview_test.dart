import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/widgets/post_link_preview.dart';

void main() {
  final previewUrl = Uri.parse('https://example.com/story?id=42');

  test('URL-only post hides the represented preview URL', () {
    expect(
      displayTextWithoutPreviewUrl(
        'https://example.com/story?id=42',
        previewUrl,
      ),
      isEmpty,
    );
  });

  test('post text remains while its represented URL is hidden', () {
    expect(
      displayTextWithoutPreviewUrl(
        'This is worth reading.\nhttps://example.com/story?id=42',
        previewUrl,
      ),
      'This is worth reading.',
    );
  });

  test(
    'only one represented URL is hidden from a post with multiple links',
    () {
      expect(
        displayTextWithoutPreviewUrl(
          'First https://example.com/story?id=42, then '
          'https://another.example/article.',
          previewUrl,
        ),
        'First, then https://another.example/article.',
      );
    },
  );

  test('a URL remains visible when no usable preview represents it', () {
    const text = 'Read https://example.com/story?id=42';
    expect(displayTextWithoutPreviewUrl(text, null), text);
    expect(
      displayTextWithoutPreviewUrl(
        text,
        Uri.parse('https://different.example/story'),
      ),
      text,
    );
  });

  test('surrounding punctuation is not consumed with the URL', () {
    expect(
      displayTextWithoutPreviewUrl(
        'Recommended (https://example.com/story?id=42)!',
        previewUrl,
      ),
      'Recommended ()!',
    );
  });

  test('scheme-less supported video links are removed when previewed', () {
    expect(
      displayTextWithoutPreviewUrl(
        'Watch youtu.be/dQw4w9WgXcQ now',
        Uri.parse('https://youtu.be/dQw4w9WgXcQ'),
      ),
      'Watch now',
    );
  });

  test('Markdown autolink URL labels are hidden with their preview', () {
    final youtube = Uri.parse(
      'https://youtu.be/lHJe_FKy5-Y?si=vmg5ml3lM_mo5nSP',
    );
    expect(
      displayTextWithoutPreviewUrl(
        r'[https://youtu\.be/lHJe\_FKy5\-Y?si=vmg5ml3lM\_mo5nSP]'
        r'(https://youtu.be/lHJe_FKy5-Y?si=vmg5ml3lM_mo5nSP)',
        youtube,
      ),
      isEmpty,
    );
  });

  test('escaped raw YouTube URLs are matched by video identity', () {
    expect(
      displayTextWithoutPreviewUrl(
        r'https://youtu.be/lHJe\_FKy5-Y?si=different\_tracking',
        Uri.parse('https://youtu.be/lHJe_FKy5-Y'),
      ),
      isEmpty,
    );
  });

  test('custom Markdown link labels remain visible', () {
    const text =
        '[Watch my video](https://youtu.be/lHJe_FKy5-Y?si=vmg5ml3lM_mo5nSP)';
    expect(
      displayTextWithoutPreviewUrl(
        text,
        Uri.parse('https://youtu.be/lHJe_FKy5-Y?si=vmg5ml3lM_mo5nSP'),
      ),
      text,
    );
  });

  testWidgets('shared PostCard hides the represented YouTube URL', (
    tester,
  ) async {
    const url = 'https://youtu.be/lHJe_FKy5-Y?si=vmg5ml3lM_mo5nSP';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'News',
            icon: '📰',
            community: 'Comunidad MP',
            author: 'michael paliz',
            time: '2 days',
            text: url,
            showActions: false,
            showMenu: false,
          ),
        ),
      ),
    );

    expect(find.text(url), findsNothing);
    expect(find.text('youtube.com'), findsOneWidget);
  });
}
