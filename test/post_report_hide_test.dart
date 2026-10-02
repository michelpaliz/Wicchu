import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/post_card.dart';

void main() {
  testWidgets('reporter can hide a reported post from the snackbar', (
    tester,
  ) async {
    final hideValues = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: 'chat',
            community: 'Test community',
            author: 'Another member',
            time: 'Now',
            text: 'Content the reporter does not want to see',
            onReport: (reason, category, {hidePost}) async {
              hideValues.add(hidePost == true);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Harassing content');
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(hideValues, [false]);
    expect(find.text('Hide post'), findsOneWidget);

    await tester.tap(find.text('Hide post'));
    await tester.pumpAndSettle();

    expect(hideValues, [false, true]);
    expect(
      find.text('Content the reporter does not want to see'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
