import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/post_markdown.dart';

void main() {
  testWidgets(
    'rich preview preserves nested mention links at large text scale',
    (tester) async {
      String? openedUser;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 288,
                child: PostMarkdown(
                  data:
                      '[**@Ana**](wicchu://user/ana) 🌿\n\n'
                      '${List.filled(12, 'More community news.').join(' ')}',
                  collapsible: true,
                  onUserTap: (id) => openedUser = id,
                ),
              ),
            ),
          ),
        ),
      );
      final preview = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('expand-post')),
          matching: find.byType(Text),
        ),
      );
      final spans = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          spans.add(span);
          for (final child in span.children ?? <InlineSpan>[]) {
            collect(child);
          }
        }
      }

      collect(preview.textSpan!);
      expect(spans.any((s) => s.style?.fontWeight == FontWeight.w700), isTrue);
      final mention = spans.singleWhere((s) => s.text == '@Ana');
      (mention.recognizer! as TapGestureRecognizer).onTap!();
      expect(openedUser, 'ana');
      expect(preview.textSpan!.toPlainText(), contains('🌿'));
      expect(preview.textSpan!.toPlainText(), endsWith('… See more'));
      final painter = TextPainter(
        text: preview.textSpan,
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2),
        maxLines: 3,
      )..layout(maxWidth: 288);
      expect(painter.didExceedMaxLines, isFalse);
      painter.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long previews expand in place and can collapse again', (
    tester,
  ) async {
    final content = List.generate(
      12,
      (i) => 'Neighborhood update number $i',
    ).join('\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PostMarkdown(data: content, collapsible: true),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('expand-post')), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    final preview = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('expand-post')),
        matching: find.byType(Text),
      ),
    );
    expect(preview.textSpan!.toPlainText(), endsWith('… See more'));
    final painter = TextPainter(
      text: preview.textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 320);
    expect(painter.didExceedMaxLines, isFalse);
    painter.dispose();
    await tester.tap(find.byKey(const ValueKey('expand-post')));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expand-post')), findsOneWidget);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('expanded text lets the feed scroll on $platform', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      String? openedUser;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ListView(
                controller: controller,
                children: [
                  PostMarkdown(
                    data:
                        '[**@Ana**](wicchu://user/ana)\n\n'
                        '${List.filled(80, 'Community news and updates.').join(' ')}',
                    collapsible: true,
                    onUserTap: (id) => openedUser = id,
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('expand-post')));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);

      await tester.tapAt(const Offset(24, 12));
      await tester.pumpAndSettle();
      expect(openedUser, 'ana');

      // A finger resting on the description must not start selecting text
      // and take over the subsequent vertical drag from the feed.
      final gesture = await tester.startGesture(const Offset(140, 280));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(0, -160));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(80));
      expect(find.byKey(const ValueKey('expand-post')), findsNothing);

      await tester.dragFrom(const Offset(140, 120), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview decodes escapes and preserves literal punctuation', (
    tester,
  ) async {
    final content =
        r'Perfecto\. **Hola** \*literal\* `C:\temp`'
        '\n\n${List.filled(20, 'More details about the neighborhood.').join('\n')}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: PostMarkdown(data: content, collapsible: true),
          ),
        ),
      ),
    );
    final preview = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('expand-post')),
        matching: find.byType(Text),
      ),
    );
    final text = preview.textSpan!.toPlainText();
    expect(text, contains(r'Perfecto. Hola *literal* C:\temp'));
    expect(text, isNot(contains(r'Perfecto\.')));
  });

  testWidgets('short posts do not have an expansion button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PostMarkdown(data: 'Hello neighbors', collapsible: true),
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });
}
