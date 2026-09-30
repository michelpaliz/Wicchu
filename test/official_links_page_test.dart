import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/official_links_page.dart';

void main() {
  testWidgets(
    'official link validates, previews and saves a Telegram address',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      List<CommunityLink> saved = [];
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialLinksPage(
            links: const [],
            onChanged: (links) => saved = links,
          ),
        ),
      );
      await tester.tap(find.text('Add link'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Telegram'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Use a valid HTTPS profile link.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).last,
        't.me/mycommunity',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('official-link-preview')),
        findsOneWidget,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved.single.url, 'https://t.me/mycommunity');
      expect(saved.single.label, 'Telegram');
      expect(tester.takeException(), isNull);
    },
  );
}
