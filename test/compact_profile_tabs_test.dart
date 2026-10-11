import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/widgets/feed_filter_bar.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('profile tabs remain visible and selectable at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setState) => FeedFilterBar(
                    compact: true,
                    style: FeedNavigationStyle.underline,
                    labels: const [
                      'Publicaciones',
                      'Multimedia',
                      'Votaciones',
                      'Guardados',
                    ],
                    selectedIndex: selected,
                    onSelected: (value) => setState(() => selected = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final label in [
        'Publicaciones',
        'Multimedia',
        'Votaciones',
        'Guardados',
      ]) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('Guardados'));
      await tester.pump();
      expect(selected, 3);
      expect(tester.takeException(), isNull);
    });
  }
}
