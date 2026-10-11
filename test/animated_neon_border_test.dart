import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/widgets/animated_neon_border.dart';

void main() {
  testWidgets('animated border becomes static when reduced motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(
          body: Center(
            child: AnimatedNeonBorder(
              color: Colors.cyan,
              enabled: true,
              animation: NeonBorderAnimation.snake,
              durationSeconds: 5,
              child: SizedBox(
                key: ValueKey('border-content'),
                width: 80,
                height: 80,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('border-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animated border ticks safely and stops after leaving the tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedNeonBorder(
            color: Colors.pink,
            enabled: true,
            animation: NeonBorderAnimation.aurora,
            durationSeconds: 4,
            child: SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('animated border pauses while its route ticker is offscreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: AnimatedNeonBorder(
            color: Colors.lime,
            enabled: true,
            animation: NeonBorderAnimation.breathing,
            durationSeconds: 5,
            child: SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
