import 'package:wicchu/domain/community_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/features/community/business_request_pages.dart';

class _RetrySettingsRepository extends DemoCommunityRepository {
  int attempts = 0;
  @override
  Future<BusinessRequestSettings> getBusinessRequestSettings(
    String businessId,
  ) async {
    if (++attempts == 1) throw Exception('Temporary failure');
    return super.getBusinessRequestSettings(businessId);
  }
}

void main() {
  testWidgets('business request settings recover after retry', (tester) async {
    final repository = _RetrySettingsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessRequestSettingsPage(
          businessId: 'business-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.attempts, 2);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer can submit a general service request', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessRequestComposerPage(
          businessId: 'business-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'What service do you need?'),
      'Garden maintenance',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Describe what you need'),
      'Trim the garden and inspect the irrigation system.',
    );
    await tester.scrollUntilVisible(
      find.text('Send request'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('Request sent'), findsOneWidget);
    expect(find.textContaining('#2001'), findsOneWidget);
    expect(
      (await repository.listMyBusinessRequests()).single.serviceName,
      'Garden maintenance',
    );
  });
}
