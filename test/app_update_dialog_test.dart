import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/services/app_update_service.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/widgets/app_update_dialog.dart';

AppUpdateInfo update({bool required = false, String notes = ''}) =>
    AppUpdateInfo(
      latestVersion: '1.0.2',
      latestBuild: 29,
      required: required,
      updateUrl: 'https://apps.apple.com/app/wicchu',
      releaseNotes: notes,
    );

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    required Future<bool> Function() action,
    bool required = false,
    String notes = '',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: !required,
                builder: (_) => AppUpdateDialog(
                  update: update(required: required, notes: notes),
                  onUpdate: action,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'optional update blocks outside dismissal while opening then closes on success',
    (tester) async {
      final pending = Completer<bool>();
      await openDialog(tester, action: () => pending.future);
      await tester.tap(find.text('Update now'));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(AppUpdateDialog), findsOneWidget);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mandatory update stays open after launching and system back', (
    tester,
  ) async {
    await openDialog(tester, required: true, action: () async => true);
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing dialog while store launch fails is safe', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await openDialog(tester, action: () => pending.future);
    await tester.tap(find.text('Update now'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.completeError(StateError('Store failed'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'error beneath long notes scrolls into view and remains retryable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openDialog(
        tester,
        notes: List.filled(50, 'New community features.').join('\n'),
        action: () async => throw StateError('Offline'),
      );
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open the store. Please try again.').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Update now').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('long Spanish update fits small screen dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: AppUpdateDialog(
              update: update(
                notes: List.filled(
                  25,
                  'Mejoras en las comunidades y la búsqueda de localidades.',
                ).join('\n'),
              ),
              onUpdate: () async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Actualizar ahora').hitTestable(), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'update shows progress, prevents duplicate taps, and retries errors',
    (tester) async {
      var calls = 0;
      final pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(
              update: update(),
              onUpdate: () {
                calls++;
                return calls == 1 ? pending.future : Future.value(false);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Update now'));
      await tester.pump();
      expect(find.text('Opening update…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Later'))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.completeError(StateError('Store unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open the store. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.text('Could not open the store. Please try again.'),
        findsNothing,
      );
      expect(find.text('Update now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('required update cannot be dismissed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(
            update: update(required: true),
            onUpdate: () async => false,
          ),
        ),
      ),
    );
    expect(find.text('Later'), findsNothing);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });
}
