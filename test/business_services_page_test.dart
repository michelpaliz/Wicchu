import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/business_services_page.dart';

void main() {
  testWidgets('local businesses can select up to 10 service chips', (
    tester,
  ) async {
    Set<BusinessService> selected = {};
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessServicesPage(
          services: const {},
          onChanged: (services) => selected = services,
        ),
      ),
    );

    for (final service in BusinessService.values.take(maxBusinessServices)) {
      final label = find.text(service.label);
      await tester.ensureVisible(label);
      await tester.tap(label);
      await tester.pump();
    }

    expect(selected.length, maxBusinessServices);
    expect(find.text('10/10'), findsOneWidget);

    final eleventh = find.text(
      BusinessService.values.elementAt(maxBusinessServices).label,
    );
    await tester.ensureVisible(eleventh);
    await tester.tap(eleventh);
    await tester.pump();

    expect(selected.length, maxBusinessServices);
    expect(
      find.text('Choose no more than 10 business services.'),
      findsOneWidget,
    );
  });
}
