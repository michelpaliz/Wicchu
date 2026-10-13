import 'package:flutter/material.dart';

/// Full profile text with compact paragraph breaks, preserving accessibility
/// scaling and the stored description rather than truncating it.
Text compactProfileDescription(BuildContext context, String text, {Key? key}) {
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
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 13,
      height: 19 / 13,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
