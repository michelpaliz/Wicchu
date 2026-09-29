import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/official_links_page.dart';

void main() {
  testWidgets('links use page navigation and keep edits when returning', (
    tester,
  ) async {
    var links = <CommunityLink>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OfficialLinksPage(
          links: links,
          onChanged: (value) => links = value,
        ),
      ),
    );
    await tester.tap(find.text('Add link'));
    await tester.pumpAndSettle();
    expect(find.text('Add official link'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'Website');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'http://example.com',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Use a valid HTTPS profile link.'), findsOneWidget);
    expect(links, isEmpty);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://example.com',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Official links'), findsOneWidget);
    expect(links.single.url, 'https://example.com');
    await tester.tap(find.text('Website'));
    await tester.pumpAndSettle();
    expect(find.text('Edit official link'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Changed');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(links.single.label, 'Website');
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(links, isEmpty);
  });
}
