import 'package:flutter/material.dart';
import '../../localization/app_language.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PostMarkdown extends StatefulWidget {
  const PostMarkdown({super.key, required this.data, this.collapsible = false});

  final String data;
  final bool collapsible;

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
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(height: 1.3);
    final preview = widget.data
        .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAll(RegExp(r'[*_`#>]'), '');
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionStyle = style.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
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
                      : announcement && i == 1
                      ? style.copyWith(fontWeight: FontWeight.w600)
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
            maxLines: 5,
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
            child: Text.rich(spanFor(excerpt, more: true), maxLines: 5),
          ),
        );
      },
    );
  }

  Widget _markdown(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: widget.data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(
          height: widget.collapsible ? 1.3 : 1.45,
        ),
        strong: theme.textTheme.bodyLarge?.copyWith(
          height: widget.collapsible ? 1.3 : 1.45,
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
