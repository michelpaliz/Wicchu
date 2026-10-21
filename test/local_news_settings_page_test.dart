import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/local_news_settings_page.dart';
import 'package:wicchu/localization/app_language.dart';

Community _community() => Community(
  id: 'community-1',
  name: 'Games Hub',
  description: '',
  town: const Town(id: 'town-1', name: 'Dénia', countryCode: 'ES'),
  visibility: CommunityVisibility.public,
  createdBy: 'owner',
  createdAt: DateTime.utc(2026),
  myRole: CommunityRole.admin,
  canManageLocalNews: true,
);

Future<void> _pump(
  WidgetTester tester,
  DemoCommunityRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (_, child) => AppLanguageScope(
        languageCode: 'en',
        onLanguageChanged: (_) {},
        child: child!,
      ),
      home: LocalNewsSettingsPage(
        community: _community(),
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NewsRepository extends DemoCommunityRepository {
  _NewsRepository(this.value);
  LocalNewsSettings value;
  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String _) async => value;
}

void main() {
  testWidgets('first use displays the required activation form', (
    tester,
  ) async {
    await _pump(tester, _NewsRepository(const LocalNewsSettings()));
    expect(find.text('Activate automated news'), findsOneWidget);
    expect(find.text('1. Post category *'), findsOneWidget);
    expect(find.text('2. What news should Wicchu look for? *'), findsOneWidget);
    expect(find.text('5. Publication mode *'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Approved sources'), findsNothing);
  });

  testWidgets(
    'source preparation reports real state without a fake percentage',
    (tester) async {
      const rule = LocalNewsRule(
        categoryId: 'category-1',
        include: 'Gaming releases, Nintendo, PlayStation and Xbox updates.',
      );
      await _pump(
        tester,
        _NewsRepository(
          LocalNewsSettings(
            activationRequested: true,
            sourcePreparationStatus: 'queued',
            newsRules: [rule],
            dashboard: LocalNewsDashboard(
              status: 'discovering_sources',
              serviceState: 'discovering_sources',
              view: 'preparation',
              quotaResetsAt: DateTime.utc(2026, 10, 23),
            ),
          ),
        ),
      );
      expect(find.text('Preparing your news'), findsOneWidget);
      expect(
        find.textContaining('searching for and verifying relevant sources'),
        findsOneWidget,
      );
      expect(find.textContaining('%'), findsNothing);
    },
  );

  testWidgets('no-news state promises a later check, not a publication', (
    tester,
  ) async {
    const rule = LocalNewsRule(
      categoryId: 'category-1',
      include: 'Gaming releases, Nintendo, PlayStation and Xbox updates.',
    );
    await _pump(
      tester,
      _NewsRepository(
        LocalNewsSettings(
          enabled: true,
          activationRequested: true,
          sourceIds: const ['source-1'],
          newsRules: const [rule],
          dashboard: LocalNewsDashboard(
            status: 'no_news_found',
            serviceState: 'active',
            view: 'dashboard',
            nextCollectionAt: DateTime.utc(2026, 10, 22),
            quotaResetsAt: DateTime.utc(2026, 10, 23),
          ),
        ),
      ),
    );
    expect(find.text('Everything is working'), findsOneWidget);
    expect(
      find.textContaining('keep looking for relevant news'),
      findsOneWidget,
    );
    expect(find.text('Next news check'), findsOneWidget);
  });
}
