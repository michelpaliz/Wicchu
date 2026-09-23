import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/post_markdown.dart';

void main() {
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
    await tester.tap(find.byKey(const ValueKey('expand-post')));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsWidgets);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expand-post')), findsOneWidget);
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
