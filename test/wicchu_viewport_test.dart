import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/widgets/wicchu_viewport.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1024, 1366),
    const Size(1366, 1024),
    const Size(375, 1024),
  ]) {
    testWidgets('viewport, routes and dialogs adapt to $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => WicchuViewport(child: child!),
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold(key: ValueKey('page'), body: TextField());
            },
          ),
        ),
      );
      final width = size.width > 600 ? 600.0 : size.width;
      expect(tester.getSize(find.byKey(const ValueKey('page'))).width, width);
      expect(MediaQuery.sizeOf(pageContext).width, width);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('page'))).dx,
        (size.width - width) / 2,
      );
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(title: Text('Dialog')),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byType(AlertDialog)).dx, size.width / 2);
      Navigator.pop(pageContext);
      await tester.pumpAndSettle();
      Navigator.push(
        pageContext,
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(key: ValueKey('next')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('next'))).width, width);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('viewport preserves keyboard and safe area insets', (
    tester,
  ) async {
    late MediaQueryData result;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1024, 1366),
            padding: EdgeInsets.only(top: 24, bottom: 20),
            viewInsets: EdgeInsets.only(bottom: 300),
            viewPadding: EdgeInsets.only(top: 24, bottom: 20),
          ),
          child: WicchuViewport(
            child: Builder(
              builder: (context) {
                result = MediaQuery.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(result.viewInsets.bottom, 300);
    expect(result.padding.top, 24);
    expect(result.viewPadding.bottom, 20);
  });
}
