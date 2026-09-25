import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/settings/account_settings_page.dart';

void main() {
  testWidgets(
    'help searches answers, expands FAQs and restores cleared results',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpPage()));
      await tester.enterText(find.byType(TextField), 'moderators');
      await tester.pumpAndSettle();
      expect(find.text('How do I join a community?'), findsNothing);
      await tester.tap(find.text('How do I report a post?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Open the post’s options menu'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'no matching answer');
      await tester.pumpAndSettle();
      expect(
        find.text('No answers found. Try another search or contact support.'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
}
