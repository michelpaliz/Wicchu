import 'dart:async';
import 'package:wicchu/theme/theme_menu.dart';
import 'package:wicchu/localization/app_language.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/auth_gateway.dart';
import 'package:wicchu/features/auth/login_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

class _AppleGateway implements AuthGateway {
  var calls = 0;
  Completer<AuthSession> result = Completer<AuthSession>();
  @override
  Future<AuthSession> signInWithApple() {
    calls++;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Spanish Apple login disables duplicates, retries and completes',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = _AppleGateway();
      var signedIn = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => AppThemeScope(
            themeMode: ThemeMode.light,
            onThemeChanged: (_) {},
            child: AppLanguageScope(
              languageCode: Localizations.localeOf(context).languageCode,
              onLanguageChanged: (_) {},
              child: child!,
            ),
          ),
          theme: WicchuTheme.light,
          locale: const Locale('es'),
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: LoginPage(authGateway: gateway, onSignedIn: () => signedIn++),
        ),
      );
      await tester.pumpAndSettle();
      final apple = find.widgetWithText(OutlinedButton, 'Continuar con Apple');
      await tester.ensureVisible(apple);
      await tester.tap(apple);
      await tester.pump();
      expect(gateway.calls, 1);
      for (final button in tester.widgetList<ButtonStyleButton>(
        find.byType(OutlinedButton),
      )) {
        expect(button.onPressed, isNull);
      }
      gateway.result.completeError(
        const AuthException('Apple sign-in is unavailable.'),
      );
      await tester.pumpAndSettle();
      expect(signedIn, 0);
      expect(tester.widget<OutlinedButton>(apple).onPressed, isNotNull);
      gateway.result = Completer<AuthSession>();
      await tester.tap(apple);
      await tester.pump();
      gateway.result.complete(
        const AuthSession(
          accessToken: 'test',
          refreshToken: 'test',
          userId: '1',
          userName: 'test',
          isNewUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.calls, 2);
      expect(signedIn, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('Android keeps its existing sign-in options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppThemeScope(
          themeMode: ThemeMode.light,
          onThemeChanged: (_) {},
          child: AppLanguageScope(
            languageCode: Localizations.localeOf(context).languageCode,
            onLanguageChanged: (_) {},
            child: child!,
          ),
        ),
        home: LoginPage(authGateway: _AppleGateway(), onSignedIn: () {}),
      ),
    );
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
