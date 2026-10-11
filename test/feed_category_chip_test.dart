import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/widgets/feed_category_chip.dart';

Widget subject({required int unreadCount, bool pulse = false}) => MaterialApp(
  home: Scaffold(
    body: FeedCategoryChip(
      label: 'News',
      selected: false,
      unreadCount: unreadCount,
      pulse: pulse,
      onSelected: () {},
    ),
  ),
);

void main() {
  testWidgets('shows a dot for one unread post', (tester) async {
    await tester.pumpWidget(subject(unreadCount: 1));
    expect(find.text('News'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('shows a counter for multiple unread posts', (tester) async {
    await tester.pumpWidget(subject(unreadCount: 3, pulse: true));
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('caps large unread counters', (tester) async {
    await tester.pumpWidget(subject(unreadCount: 120));
    expect(find.text('99+'), findsOneWidget);
  });
}
