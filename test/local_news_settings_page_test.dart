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
  DemoCommunityRepository repository, {
  String languageCode = 'en',
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(languageCode),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (_, child) => AppLanguageScope(
        languageCode: languageCode,
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

class _CategoryNewsRepository extends _NewsRepository {
  _CategoryNewsRepository(super.value);

  @override
  Future<List<CommunityCategory>> listCategories(String communityId) async => [
    const CommunityCategory(
      id: 'news',
      communityId: 'community-1',
      name: 'News',
      icon: '📰',
    ),
    const CommunityCategory(
      id: 'businesses',
      communityId: 'community-1',
      name: 'Local Businesses',
      icon: '📍',
    ),
  ];
}

void main() {
  List<String> categoryLabels(WidgetTester tester) {
    final field = find.byType(DropdownButtonFormField<String>).first;
    final dropdown = tester.widget<DropdownButton<String>>(
      find.descendant(of: field, matching: find.byType(DropdownButton<String>)),
    );
    return dropdown.items!
        .map((item) => (item.child as Text).data ?? '')
        .toList(growable: false);
  }

  testWidgets('built-in categories follow the selected app language', (
    tester,
  ) async {
    await _pump(
      tester,
      _CategoryNewsRepository(const LocalNewsSettings()),
      languageCode: 'es',
    );
    expect(
      categoryLabels(tester),
      containsAll(['Noticias', 'Negocios locales']),
    );
    expect(categoryLabels(tester), isNot(contains('News')));
  });

  testWidgets('category language follows app preference during locale switch', (
    tester,
  ) async {
    await _pump(
      tester,
      _CategoryNewsRepository(const LocalNewsSettings()),
      languageCode: 'es',
    );
    expect(categoryLabels(tester), contains('Noticias'));

    // The app preference remains authoritative while Flutter is still using
    // the previous platform locale during a language transition.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (_, child) => AppLanguageScope(
          languageCode: 'es',
          onLanguageChanged: (_) {},
          child: child!,
        ),
        home: LocalNewsSettingsPage(
          community: _community(),
          repository: _CategoryNewsRepository(const LocalNewsSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(categoryLabels(tester), contains('Noticias'));
    expect(categoryLabels(tester), isNot(contains('News')));
  });

  testWidgets('first use displays the required activation form', (
    tester,
  ) async {
    await _pump(
      tester,
      _NewsRepository(
        const LocalNewsSettings(
          access: LocalNewsAccess(
            entitled: true,
            source: 'pilot',
            tier: 'pilot',
          ),
        ),
      ),
    );
    expect(find.text('Activate automated news'), findsOneWidget);
    expect(find.text('Post category *'), findsOneWidget);
    expect(find.text('News topics *'), findsOneWidget);
    expect(find.text('Publication approval'), findsOneWidget);
    expect(find.text('Publication mode *'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Approved sources'), findsNothing);
  });

  testWidgets('first use shows concise validation before activation', (
    tester,
  ) async {
    await _pump(
      tester,
      _NewsRepository(
        const LocalNewsSettings(
          access: LocalNewsAccess(
            entitled: true,
            source: 'pilot',
            tier: 'pilot',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Select a category for these news posts.'),
      findsOneWidget,
    );
    expect(find.text('Describe the news Wicchu should find.'), findsOneWidget);
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
