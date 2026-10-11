import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wicchu/features/profile/profile_empty_state.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Spanish empty profile actions work in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var created = 0;
        var explored = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileEmptyState(
                  onCreate: () => created++,
                  onExplore: () => explored++,
                ),
              ),
            ),
          ),
        );
        expect(find.text('Aún no has compartido nada'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('profile-first-post')),
        );
        await tester.tap(find.byKey(const ValueKey('profile-first-post')));
        await tester.ensureVisible(find.text('Explorar comunidades'));
        await tester.tap(find.text('Explorar comunidades'));
        expect(created, 1);
        expect(explored, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
