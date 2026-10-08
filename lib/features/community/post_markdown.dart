import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import '../../localization/app_language.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

String postPlainText(String source, {bool preserveParagraphs = false}) {
  final document = md.Document(
    encodeHtml: false,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  String render(md.Node node) {
    if (node is md.Text) return node.text;
    if (node is! md.Element) return node.textContent;
    if (node.tag == 'img') return node.attributes['alt'] ?? '';
    if (node.tag == 'br') return '\n';
    final text = (node.children ?? []).map(render).join();
    const blocks = {
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
      'blockquote',
      'pre',
      'ul',
      'ol',
    };
    if (preserveParagraphs &&
        {
          'p',
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
          'blockquote',
          'pre',
        }.contains(node.tag)) {
      return '$text\n\n';
    }
    return blocks.contains(node.tag) ? '$text\n' : text;
  }

  return document
      .parseLines(source.split('\n'))
      .map(render)
      .join()
      .replaceAll(RegExp(r'\n[ \t]*\n+'), preserveParagraphs ? '\n\n' : '\n')
      .trim();
}

class PostMarkdown extends StatefulWidget {
  const PostMarkdown({
    super.key,
    required this.data,
    this.collapsible = false,
    this.compact = false,
    this.previewLines = 5,
    this.onUserTap,
  });

  final String data;
  final bool collapsible;
  final bool compact;
  final int previewLines;
  final ValueChanged<String>? onUserTap;

  @override
  State<PostMarkdown> createState() => _PostMarkdownState();
}

class _PostMarkdownState extends State<PostMarkdown> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant PostMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.collapsible) return _markdown(context);
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
    final preview = postPlainText(widget.data);
    final firstParagraph = widget.data.trim().split(RegExp(r'\n\s*\n')).first;
    final hasHeadline =
        widget.data.trim().contains(RegExp(r'\n\s*\n')) &&
        firstParagraph.length <= 120 &&
        !firstParagraph.contains('\n');
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionStyle = style.copyWith(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        );
        TextSpan spanFor(String text, {bool more = false}) {
          final lines = text.split('\n');
          final announcement =
              preview.startsWith('📢') || preview.startsWith('📣');
          return TextSpan(
            style: style,
            children: [
              for (var i = 0; i < lines.length; i++)
                TextSpan(
                  text: '${i == 0 ? '' : '\n'}${lines[i]}',
                  style: announcement && i == 0
                      ? style.copyWith(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )
                      : (announcement && i == 1) || (hasHeadline && i == 0)
                      ? style.copyWith(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        )
                      : null,
                ),
              if (more)
                TextSpan(
                  text: '… ${context.tr('See more')}',
                  style: actionStyle,
                ),
            ],
          );
        }

        bool fits(TextSpan span) {
          final painter = TextPainter(
            text: span,
            maxLines: widget.previewLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final result = !painter.didExceedMaxLines;
          painter.dispose();
          return result;
        }

        if (fits(spanFor(preview))) return _markdown(context);
        if (_expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _markdown(context),
              TextButton(
                onPressed: () => setState(() => _expanded = false),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: style.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(context.tr('See less')),
              ),
            ],
          );
        }
        final characters = preview.characters.toList();
        var low = 0;
        var high = characters.length;
        while (low < high) {
          final middle = (low + high + 1) ~/ 2;
          if (fits(
            spanFor(characters.take(middle).join().trimRight(), more: true),
          )) {
            low = middle;
          } else {
            high = middle - 1;
          }
        }
        var excerpt = characters.take(low).join().trimRight();
        final lastSpace = excerpt.lastIndexOf(' ');
        if (lastSpace > excerpt.length - 20 && lastSpace >= 0) {
          excerpt = excerpt.substring(0, lastSpace);
        }
        return Semantics(
          button: true,
          label: '$excerpt… ${context.tr('See more')}',
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('expand-post'),
            onTap: () => setState(() => _expanded = true),
            child: Text.rich(
              spanFor(excerpt, more: true),
              maxLines: widget.previewLines,
            ),
          ),
        );
      },
    );
  }

  // Present a short standalone opening paragraph as a headline without
  // changing the stored post or treating ordinary single-paragraph posts as titles.
  String get _displayMarkdown {
    final paragraphs = widget.data.trim().split(RegExp(r'\n\s*\n'));
    if (paragraphs.length > 1 &&
        paragraphs.first.length <= 120 &&
        !paragraphs.first.contains('\n') &&
        !RegExp(r'^[#>*\-]|^\d+\.').hasMatch(paragraphs.first)) {
      return '### ${paragraphs.first}\n\n${paragraphs.skip(1).join('\n\n')}';
    }
    return widget.data;
  }

  Widget _markdown(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: _displayMarkdown,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w400,
        ),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        h1: theme.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        h2: theme.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        h3: theme.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        blockSpacing: widget.compact ? 3 : 4,
        listIndent: 24,
      ),
      imageBuilder: (uri, title, alt) => Text(alt ?? '[image]'),
      onTapLink: (_, href, _) async {
        final uri = Uri.tryParse(href ?? '');
        if (uri == null) return;
        if (uri.scheme == 'wicchu' &&
            uri.host == 'user' &&
            uri.pathSegments.isNotEmpty) {
          widget.onUserTap?.call(uri.pathSegments.first);
          return;
        }
        if (!{'http', 'https'}.contains(uri.scheme)) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}
