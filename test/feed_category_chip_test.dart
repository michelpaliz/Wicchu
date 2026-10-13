import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/widgets/feed_category_chip.dart';
import 'package:wicchu/widgets/feed_filter_bar.dart';

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
  for (final brightness in Brightness.values) {
    testWidgets(
      'unread badges stay compact inside the scrolling bar in $brightness',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: FeedFilterBar(
                  labels: const ['All', 'Market', 'General', 'News'],
                  unreadCounts: const [1, 3, 0, 120],
                  selectedIndex: 2,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        final badges = find.byKey(const ValueKey('category-unread-badge'));
        expect(tester.getSize(badges.at(0)), const Size(6, 6));
        expect(tester.getSize(badges.at(1)).height, lessThanOrEqualTo(20));
        final chips = find.byType(ChoiceChip);
        final heights = List.generate(
          4,
          (index) => tester.getSize(chips.at(index)).height,
        );
        expect(heights.toSet(), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
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
