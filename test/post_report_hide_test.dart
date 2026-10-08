import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/post_card.dart';

void main() {
  testWidgets('owner menu offers share and edit without self reporting', (
    tester,
  ) async {
    var shares = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: '💬',
            community: 'Test',
            author: 'Me',
            time: 'Now',
            text: 'My post',
            onEdit: () {},
            onShare: () async {
              shares++;
            },
            onReport: (reason, category, {hidePost}) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Post options'), findsOneWidget);
    expect(find.text('Edit post'), findsOneWidget);
    expect(find.text('Report post'), findsNothing);
    await tester.tap(find.text('Share post'));
    await tester.pumpAndSettle();
    expect(shares, 1);
    expect(find.text('Post options'), findsNothing);
  });

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
    await tester.ensureVisible(find.text('Submit report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
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
