import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/localization/app_language.dart';

void main() {
  testWidgets(
    'notification invitations follow the locale without translating names',
    (tester) async {
      const name = 'Mantenimiento Michel S.L';
      const message = 'invited you to become an administrator of $name';
      Future<void> show(String language, String text) => tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Text(context.trNotification(text)),
          ),
        ),
      );
      await show('es', message);
      await tester.pumpAndSettle();
      expect(
        find.text('te invitó a ser administrador de $name'),
        findsOneWidget,
      );
      await show('en', message);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      await show('es', 'invited you to join Echeandía');
      await tester.pumpAndSettle();
      expect(find.text('te invitó a unirte a Echeandía'), findsOneWidget);
      await show('es', 'changed your role to a moderator in Echeandía');
      await tester.pumpAndSettle();
      expect(
        find.text('cambió tu rol a moderador en Echeandía'),
        findsOneWidget,
      );
    },
  );
}
