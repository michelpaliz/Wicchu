import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/features/settings/account_settings_page.dart';

void main() {
  testWidgets('nearby discovery persists its local preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsPage(repository: DemoCommunityRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nearby discovery'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nearby discovery'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool('location_discovery'),
      false,
    );
    expect(tester.takeException(), isNull);
  });
}
