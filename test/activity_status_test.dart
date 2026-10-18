import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/localization/activity_status.dart';

void main() {
  final now = DateTime(2026, 10, 18, 20);

  Future<String?> status(
    WidgetTester tester, {
    bool isOnline = false,
    DateTime? lastActiveAt,
    Locale locale = const Locale('en'),
  }) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            result = activityStatusText(
              context,
              isOnline: isOnline,
              lastActiveAt: lastActiveAt,
              now: now,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('formats friendly activity ranges', (tester) async {
    expect(await status(tester, isOnline: true), 'Active now');
    expect(
      await status(
        tester,
        lastActiveAt: now.subtract(const Duration(minutes: 5)),
      ),
      'Active 5 min ago',
    );
    expect(
      await status(
        tester,
        lastActiveAt: now.subtract(const Duration(hours: 2)),
      ),
      'Active 2 hr ago',
    );
    expect(
      await status(tester, lastActiveAt: now.subtract(const Duration(days: 3))),
      'Active 3 days ago',
    );
    expect(
      await status(tester, lastActiveAt: now.subtract(const Duration(days: 9))),
      'Active over a week ago',
    );
    expect(await status(tester), isNull);
  });

  testWidgets('localizes activity status and yesterday time', (tester) async {
    expect(
      await status(
        tester,
        lastActiveAt: DateTime(2026, 10, 17, 18, 30),
        locale: const Locale('es'),
      ),
      'Activo ayer a las 18:30',
    );
  });
}
