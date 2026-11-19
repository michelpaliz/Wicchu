import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

bool _isEmojiRune(int rune) =>
    (rune >= 0x1F1E6 && rune <= 0x1F1FF) ||
    (rune >= 0x1F300 && rune <= 0x1FAFF) ||
    (rune >= 0x2600 && rune <= 0x27BF) ||
    rune == 0x200D ||
    rune == 0xFE0F;

bool containsEmoji(String text) => text.runes.any(_isEmojiRune);

/// Apple currently renders supplementary-plane emoji as missing-glyph boxes
/// when they are mixed with Wicchu's bundled font. Keep post copy readable on
/// those platforms until the engine can use the native color emoji font.
String removeUnsupportedEmojiForDisplay(String text) {
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return text;
  }
  return text.characters
      .where((character) => !character.runes.any(_isEmojiRune))
      .join()
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r' +\n'), '\n')
      .trim();
}

String get _platformEmojiFont => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.macOS => 'AppleColorEmoji',
  TargetPlatform.android || TargetPlatform.fuchsia => 'Noto Color Emoji',
  TargetPlatform.windows => 'Segoe UI Emoji',
  TargetPlatform.linux => 'Noto Color Emoji',
};

TextSpan emojiAwareTextSpan(
  String text, {
  TextStyle? style,
  GestureRecognizer? recognizer,
}) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  bool? emojiRun;

  void flush() {
    if (buffer.isEmpty) return;
    final value = buffer.toString();
    buffer.clear();
    spans.add(
      TextSpan(
        text: value,
        recognizer: recognizer,
        style: emojiRun == true
            ? TextStyle(
                fontFamily: _platformEmojiFont,
                fontFamilyFallback: WicchuEmojiFonts.fallback,
                fontWeight: FontWeight.w400,
              )
            : null,
      ),
    );
  }

  for (final character in text.characters) {
    final isEmoji = character.runes.any(_isEmojiRune);
    if (emojiRun != null && emojiRun != isEmoji) flush();
    emojiRun = isEmoji;
    buffer.write(character);
  }
  flush();
  return TextSpan(style: style, children: spans);
}

abstract final class WicchuEmojiFonts {
  static const fallback = <String>[
    '.Apple Color Emoji UI',
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Segoe UI Emoji',
  ];
}
