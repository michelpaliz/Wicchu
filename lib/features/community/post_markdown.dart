import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PostMarkdown extends StatelessWidget {
  const PostMarkdown({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        strong: theme.textTheme.bodyLarge?.copyWith(
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
        blockSpacing: 8,
        listIndent: 24,
      ),
      imageBuilder: (uri, title, alt) => Text(alt ?? '[image]'),
      onTapLink: (_, href, _) async {
        final uri = Uri.tryParse(href ?? '');
        if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}
