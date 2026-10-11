import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_rating_sheet.dart';

void main() {
  testWidgets(
    'Spanish compact survey requires five answers and retains them on error',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: CommunityRatingSheet(
              isPage: false,
              onSubmit: (answers) async {
                submissions++;
                expect(answers, [true, false, true, false, true]);
                throw Exception('Network unavailable');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Valora esta comunidad'), findsOneWidget);
      expect(find.text('0 de 5 respondidas'), findsOneWidget);
      expect(find.text('Yes'), findsNothing);
      final submit = find.byKey(const ValueKey('rating-submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      for (var i = 0; i < 5; i++) {
        final option = find.descendant(
          of: find.byKey(ValueKey('rating-answer-$i')),
          matching: find.text(i.isEven ? 'Sí' : 'No'),
        );
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(submit.hitTestable(), findsOneWidget);
      }
      expect(find.text('5 de 5 respondidas'), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(submissions, 1);
      expect(find.text('5 de 5 respondidas'), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy partial answers are not converted into yes or no', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityRatingSheet(
            isPage: true,
            current: const CommunitySurveyResponse(
              helpful: false,
              locallyRelevant: 'sometimes',
              safeParticipation: 'yes',
              wellOrganized: 'somewhat',
              recommend: true,
            ),
            onSubmit: (_) async => throw UnimplementedError(),
          ),
        ),
      ),
    );
    expect(find.text('3 of 5 answered'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('rating-submit')))
          .onPressed,
      isNull,
    );
  });
}
