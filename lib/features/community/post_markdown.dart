import 'package:flutter/gestures.dart';
import '../../theme/wicchu_theme.dart';
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
    this.previewLines = 3,
    this.onUserTap,
    this.bodyStyle,
  });

  final String data;
  final TextStyle? bodyStyle;
  final bool collapsible;
  final bool compact;
  final int previewLines;
  final ValueChanged<String>? onUserTap;

  @override
  State<PostMarkdown> createState() => _PostMarkdownState();
}

class _PostMarkdownState extends State<PostMarkdown> {
  bool _expanded = false;
  final _linkRecognizers = <TapGestureRecognizer>[];

  void _clearRecognizers() {
    for (final recognizer in _linkRecognizers) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  Future<void> _openLink(String? href) async {
    final uri = Uri.tryParse(href ?? '');
    if (uri == null) return;
    if (uri.scheme == 'wicchu' &&
        uri.host == 'user' &&
        uri.pathSegments.isNotEmpty) {
      widget.onUserTap?.call(uri.pathSegments.first);
    } else if ({'http', 'https'}.contains(uri.scheme)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  TextSpan _previewSpan(BuildContext context) {
    final document = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
    InlineSpan render(md.Node node, {TapGestureRecognizer? link}) {
      if (node is md.Text) return TextSpan(text: node.text, recognizer: link);
      if (node is! md.Element) return TextSpan(text: node.textContent);
      if (node.tag == 'br') return const TextSpan(text: '\n');
      if (node.tag == 'img') {
        return TextSpan(text: node.attributes['alt'] ?? '');
      }
      final heading = RegExp(r'^h[1-6]$').hasMatch(node.tag);
      final block =
          heading || {'p', 'li', 'blockquote', 'pre'}.contains(node.tag);
      TapGestureRecognizer? recognizer;
      if (node.tag == 'a') {
        recognizer = TapGestureRecognizer()
          ..onTap = () => _openLink(node.attributes['href']);
        _linkRecognizers.add(recognizer);
      }
      return TextSpan(
        style: heading
            ? WicchuPostTypography.title(context)
            : switch (node.tag) {
                'strong' => const TextStyle(fontWeight: FontWeight.w700),
                'em' => const TextStyle(fontStyle: FontStyle.italic),
                'del' => const TextStyle(
                  decoration: TextDecoration.lineThrough,
                ),
                'code' => const TextStyle(fontFamily: 'monospace'),
                'a' => TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                _ => null,
              },
        // Recognizers must live on leaf spans for inline links to remain tappable.
        children: [
          if (node.tag == 'li') const TextSpan(text: '• '),
          ...(node.children ?? []).map(
            (child) => render(child, link: recognizer ?? link),
          ),
          if (block) const TextSpan(text: '\n'),
        ],
      );
    }

    return TextSpan(
      style: (widget.bodyStyle ?? WicchuPostTypography.body(context)),
      children: document
          .parseLines(_displayMarkdown.split('\n'))
          .map(render)
          .toList(),
    );
  }

  @override
  void didUpdateWidget(covariant PostMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    if (!widget.collapsible) return _markdown(context);
    final span = _previewSpan(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: span,
          maxLines: widget.previewLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        if (!overflows) return _markdown(context);
        if (!_expanded) {
          final preview = _inlinePreview(context, span, constraints.maxWidth);
          return InkWell(
            key: const ValueKey('expand-post'),
            onTap: () => setState(() => _expanded = true),
            child: Text.rich(preview),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _markdown(context),
            TextButton(
              onPressed: () => setState(() => _expanded = false),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 32),
                tapTargetSize: MaterialTapTargetSize.padded,
                alignment: Alignment.centerLeft,
                textStyle: WicchuPostTypography.action(context),
              ),
              child: Text(context.tr('See less')),
            ),
          ],
        );
      },
    );
  }

  // Fit the action into the last preview line without flattening styled links
  // or splitting an emoji, combining character, or surrogate pair.
  TextSpan _inlinePreview(BuildContext context, TextSpan source, double width) {
    final text = source.toPlainText();
    final offsets = <int>[0];
    for (final character in text.characters) {
      offsets.add(offsets.last + character.length);
    }
    TextSpan prefix(int length) {
      var remaining = length;
      TextSpan take(TextSpan span) {
        final value = span.text ?? '';
        final count = remaining.clamp(0, value.length);
        remaining -= count;
        return TextSpan(
          text: value.substring(0, count),
          style: span.style,
          recognizer: span.recognizer,
          children: [
            for (final child in span.children ?? <InlineSpan>[])
              if (remaining > 0 && child is TextSpan) take(child),
          ],
        );
      }

      // Trim trailing block breaks before placing the inline action.
      final trimmedLength = text.substring(0, length).trimRight().length;
      remaining = trimmedLength;
      return TextSpan(
        style: source.style,
        children: [
          take(source),
          const TextSpan(text: '… '),
          TextSpan(
            text: context.tr('See more'),
            style: WicchuPostTypography.action(context),
          ),
        ],
      );
    }

    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: widget.previewLines,
    );
    var low = 0;
    var high = offsets.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      painter.text = prefix(offsets[middle]);
      painter.layout(maxWidth: width);
      if (painter.didExceedMaxLines) {
        high = middle - 1;
      } else {
        low = middle;
      }
    }
    painter.dispose();
    return prefix(offsets[low]);
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
        p: (widget.bodyStyle ?? WicchuPostTypography.body(context)),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        h1: WicchuPostTypography.title(context),
        h2: WicchuPostTypography.title(context),
        h3: WicchuPostTypography.title(context),
        h4: WicchuPostTypography.title(context),
        h5: WicchuPostTypography.title(context),
        h6: WicchuPostTypography.title(context),
        blockSpacing: widget.compact ? 3 : 4,
        listIndent: 24,
      ),
      imageBuilder: (uri, title, alt) => Text(alt ?? '[image]'),
      onTapLink: (_, href, _) => _openLink(href),
    );
  }
}
