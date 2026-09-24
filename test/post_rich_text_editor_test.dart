import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:wicchu/features/community/post_rich_text_editor.dart';

void main() {
  test('existing formatting loads visually and untouched posts remain exact', () {
    const original =
        '# Neighbors\n\n**Welcome** and *hello*\n\n- One\n- Two\n\n[Visit](https://example.com)\n';
    final controller = PostTextController(original);
    addTearDown(controller.dispose);
    expect(controller.document.toPlainText(), contains('Welcome and hello'));
    expect(controller.document.toPlainText(), isNot(contains('**')));
    expect(controller.document.toPlainText(), isNot(contains('https://')));
    expect(controller.text, original);
    controller.formatText(0, 9, quill.Attribute.bold);
    final rendered = md.markdownToHtml(controller.text);
    expect(rendered, contains('<strong>'));
    expect(rendered, contains('<em>hello</em>'));
    expect(rendered, contains('<li>One</li>'));
    expect(rendered, contains('href="https://example.com"'));
  });

  test('formatting exports Markdown while plain typing stays literal', () {
    final controller = PostTextController('');
    addTearDown(controller.dispose);
    controller.replaceText(
      0,
      0,
      'Hello neighbors',
      const TextSelection.collapsed(offset: 15),
    );
    controller.formatText(0, 5, quill.Attribute.bold);
    controller.formatText(6, 9, quill.Attribute.italic);
    final html = md.markdownToHtml(controller.text);
    expect(html, contains('<strong>Hello</strong>'));
    expect(html, contains('<em>neighbors</em>'));
    expect(controller.document.toPlainText(), 'Hello neighbors\n');
    controller.formatText(
      0,
      5,
      quill.Attribute.clone(quill.Attribute.bold, null),
    );
    expect(md.markdownToHtml(controller.text), isNot(contains('<strong>')));
  });

  testWidgets(
    'toolbar formats the selection directly without inserting markup',
    (tester) async {
      final controller = PostTextController('Hello neighbors');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PostRichTextEditor(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        quill.ChangeSource.local,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();
      expect(controller.document.toPlainText(), 'Hello neighbors\n');
      expect(controller.getSelectionStyle().attributes['bold']?.value, true);
      expect(
        md.markdownToHtml(controller.text),
        contains('<strong>Hello</strong>'),
      );
      await tester.tap(find.byTooltip('Bold'));
      await tester.pumpAndSettle();
      expect(
        controller.getSelectionStyle().attributes['bold']?.value,
        isNot(true),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
