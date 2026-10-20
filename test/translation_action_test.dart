import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/widgets/translation_action.dart';

void main() {
  testWidgets(
    'translation states fit narrow layouts in both themes and languages',
    (tester) async {
      for (final dark in [false, true]) {
        for (final language in ['en', 'es']) {
          for (final state in ['original', 'loading', 'translated']) {
            var taps = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? WicchuTheme.dark : WicchuTheme.light,
                locale: Locale(language),
                supportedLocales: const [Locale('en'), Locale('es')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 240,
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TranslationAction(
                              translating: state == 'loading',
                              translated: state == 'translated',
                              onPressed: () => taps++,
                            ),
                            if (state == 'translated')
                              const TranslationAttribution(
                                languageCode: 'es-EC',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$dark $language $state',
            );
            expect(
              tester.getSize(find.byType(TextButton)).height,
              greaterThanOrEqualTo(48),
            );
            if (state == 'translated') {
              expect(
                find.text(
                  language == 'es'
                      ? 'Traducido automáticamente al español'
                      : 'Automatically translated to Spanish',
                ),
                findsOneWidget,
              );
            }
            await tester.tap(find.byType(TextButton));
            expect(taps, state == 'loading' ? 0 : 1);
            expect(
              find.byType(CircularProgressIndicator),
              state == 'loading' ? findsOneWidget : findsNothing,
            );
          }
        }
      }
    },
  );
}
