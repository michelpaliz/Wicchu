import 'package:flutter/material.dart';
import '../localization/app_language.dart';
import 'emoji_aware_text.dart';

bool _isInvalidDisplayRune(int rune) {
  final isDisallowedControl =
      (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) ||
      (rune >= 0x7F && rune <= 0x9F);
  final isPrivateUse =
      (rune >= 0xE000 && rune <= 0xF8FF) ||
      (rune >= 0xF0000 && rune <= 0xFFFFD) ||
      (rune >= 0x100000 && rune <= 0x10FFFD);
  final isNonCharacter =
      (rune >= 0xFDD0 && rune <= 0xFDEF) ||
      (rune & 0xFFFF) == 0xFFFE ||
      (rune & 0xFFFF) == 0xFFFF;
  return rune == 0xFFFC ||
      rune == 0xFFFD ||
      isDisallowedControl ||
      isPrivateUse ||
      isNonCharacter;
}

/// Removes malformed placeholders that cannot be rendered as user content.
/// Accents, line breaks, tabs and Markdown punctuation remain. On Apple
/// platforms, emoji that the current renderer displays as missing glyph boxes
/// are omitted so public copy remains readable.
String sanitizeDisplayText(String text) {
  final sanitized = StringBuffer();
  for (final rune in text.runes) {
    if (!_isInvalidDisplayRune(rune)) sanitized.writeCharCode(rune);
  }
  return removeUnsupportedEmojiForDisplay(sanitized.toString());
}

/// Full profile text with compact paragraph breaks, preserving accessibility
/// scaling and the stored description rather than truncating it.
Text compactProfileDescription(
  BuildContext context,
  String text, {
  Key? key,
  int? maxLines,
}) {
  text = sanitizeDisplayText(text);
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
