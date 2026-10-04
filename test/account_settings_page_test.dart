import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/auth_gateway.dart';
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

  testWidgets('signed-in user can connect Facebook', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _LinkingAuthGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsPage(
          repository: DemoCommunityRepository(),
          authGateway: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Facebook account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Facebook account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facebook account'));
    await tester.pumpAndSettle();

    expect(auth.linkCalls, 1);
    expect(find.text('Facebook account connected.'), findsOneWidget);
  });
}

class _LinkingAuthGateway implements AuthGateway, FacebookAccountLinker {
  int linkCalls = 0;

  @override
  Future<bool> isFacebookLinked() async => false;

  @override
  Future<void> linkFacebookAccount() async {
    linkCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
