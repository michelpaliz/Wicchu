import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/features/admin/local_news_settings_page.dart';
import 'package:wicchu/localization/app_language.dart';

void main() {
  testWidgets('administrator sees plans, prices, and news configuration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoCommunityRepository();
    final community = await repository.getCommunity('town-x-community');

    await tester.pumpWidget(
      AppLanguageScope(
        languageCode: 'en',
        onLanguageChanged: (_) {},
        child: MaterialApp(
          home: LocalNewsSettingsPage(
            community: community,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Automated news'), findsOneWidget);
    expect(find.text('Available plans'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('BUSINESS'), findsOneWidget);
    expect(find.textContaining('€4.99 / \$4.99 per month'), findsOneWidget);
    expect(find.textContaining('€9.99 / \$9.99 per month'), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Enable automated news'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Enable automated news'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Approved sources'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Approved sources'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('News categories'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('News categories'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save settings'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save settings'), findsOneWidget);
  });
}
