import 'package:flutter/material.dart';
import '../localization/app_language.dart';

/// Full profile text with compact paragraph breaks, preserving accessibility
/// scaling and the stored description rather than truncating it.
Text compactProfileDescription(
  BuildContext context,
  String text, {
  Key? key,
  int? maxLines,
}) {
  final spans = <InlineSpan>[];
  var start = 0;
  for (final match in RegExp(r'\n[ \t]*\n+').allMatches(text)) {
    spans.add(TextSpan(text: text.substring(start, match.start)));
    spans.add(const TextSpan(text: '\n'));
    spans.add(
      const TextSpan(text: '\n', style: TextStyle(fontSize: 5, height: 1)),
    );
    start = match.end;
  }
  spans.add(TextSpan(text: text.substring(start)));
  return Text.rich(
    TextSpan(children: spans),
    key: key,
    softWrap: true,
    maxLines: maxLines,
    overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 13,
      height: 19 / 13,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class ExpandableProfileDescription extends StatefulWidget {
  const ExpandableProfileDescription({
    super.key,
    required this.text,
    this.collapsedLines = 3,
  });
  final String text;
  final int collapsedLines;
  @override
  State<ExpandableProfileDescription> createState() =>
      _ExpandableProfileDescriptionState();
}

class _ExpandableProfileDescriptionState
    extends State<ExpandableProfileDescription> {
  bool _expanded = false;
  @override
  void didUpdateWidget(covariant ExpandableProfileDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final text = compactProfileDescription(
        context,
        widget.text,
        key: const ValueKey('page-header-description'),
        maxLines: _expanded ? null : widget.collapsedLines,
      );
      final painter = TextPainter(
        text: TextSpan(style: text.style, children: [text.textSpan!]),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: widget.collapsedLines,
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          if (overflows)
            TextButton(
              key: const ValueKey('page-header-description-toggle'),
              onPressed: () {
                if (_expanded) Scrollable.ensureVisible(context);
                setState(() => _expanded = !_expanded);
              },
              child: Text(context.tr(_expanded ? 'See less' : 'See more')),
            ),
        ],
      );
    },
  );
}
