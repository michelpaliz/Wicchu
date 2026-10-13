import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/auth_gateway.dart';
import 'package:wicchu/features/auth/login_page.dart';
import 'package:wicchu/features/onboarding/preferences_page.dart';
import 'package:wicchu/main.dart';

class _SignedOutAuth implements AuthGateway {
  @override
  Future<bool> hasSession() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app() => WicchuApp(
    repository: DemoCommunityRepository(),
    authGateway: _SignedOutAuth(),
  );

  testWidgets('settings start below header and translate immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_preferences_completed': true,
      'language': 'es',
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const PreferencesPage()));
    await tester.pumpAndSettle();
    final heading = tester.getTopLeft(find.text('Idioma'));
    final headerBottom = tester.getBottomLeft(find.byType(AppBar));
    expect(heading.dy - headerBottom.dy, inInclusiveRange(24, 32));
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('Language and appearance'), findsOneWidget);
    expect(find.text('Changes apply automatically.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'first launch detects Spanish, changes immediately, and persists completion',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [
        Locale('es', 'EC'),
      ];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(PreferencesPage), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_preferences_completed'), isNull);
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('welcome-continue')),
      );
      await tester.tap(find.byKey(const ValueKey('welcome-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(prefs.getBool('onboarding_preferences_completed'), isTrue);
      expect(prefs.getString('language'), 'en');
      expect(prefs.getString('themeMode'), 'dark');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(PreferencesPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    },
  );

  testWidgets(
    'unfinished welcome returns with saved choices and unsupported locale falls back',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [Locale('nl')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-es')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(PreferencesPage), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'onboarding_preferences_completed',
        ),
        isNull,
      );
    },
  );
}
