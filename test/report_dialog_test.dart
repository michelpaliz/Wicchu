import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/features/community/report_dialog.dart';

void main() {
  testWidgets(
    'report sheet submits a supported category with optional details',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      (String, String)? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showContentReportDialog(
                    context,
                    title: 'Report profile',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.ensureVisible(find.text('Harassment'));
      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit report'));
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();
      expect(result, ('Harassment', 'harassment'));
      expect(tester.takeException(), isNull);
    },
  );
}
