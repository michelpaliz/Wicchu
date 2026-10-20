import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/local_news_settings_page.dart';
import 'package:wicchu/features/admin/pending_posts_page.dart';
import 'package:wicchu/localization/app_language.dart';

final _next = DateTime.utc(2026, 10, 19, 21, 16, 31);
final _reset = DateTime.utc(2026, 10, 20);

LocalNewsDashboard _dashboard({
  String status = 'scheduled',
  String? reason,
  bool enabled = true,
  DateTime? nextCollectionAt,
  bool noNext = false,
  int pendingApproval = 0,
  int todayUsed = 0,
  int publishedToday = 0,
  String approvalMode = 'manual',
  LocalNewsLastRun? lastRun,
}) => LocalNewsDashboard(
  status: status,
  reason: reason,
  enabled: enabled,
  approvalMode: approvalMode,
  nextCollectionAt: noNext ? null : (nextCollectionAt ?? _next),
  quotaResetsAt: _reset,
  pendingApproval: pendingApproval,
  todayUsed: todayUsed,
  publishedToday: publishedToday,
  dailyLimit: 1,
  monthlyLimit: 60,
  lastRun: lastRun,
);

class _DashboardRepository extends DemoCommunityRepository {
  _DashboardRepository(this.dashboard, {this.forbidden = false});

  LocalNewsDashboard dashboard;
  final bool forbidden;
  var settingsLoads = 0;

  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async {
    settingsLoads += 1;
    if (forbidden) {
      throw const ApiException(
        'Local News is not available for this community',
        statusCode: 403,
      );
    }
    return LocalNewsSettings(
      enabled: dashboard.enabled,
      approvalMode: dashboard.approvalMode,
      monthlyLimit: 60,
      access: const LocalNewsAccess(
        entitled: true,
        source: 'pilot',
        tier: 'pilot',
        monthlyLimit: 60,
      ),
      dashboard: dashboard,
      lastRun: dashboard.lastRun,
    );
  }
}

class _NoSourcesRepository extends _DashboardRepository {
  _NoSourcesRepository() : super(_dashboard(status: 'paused', enabled: false));

  bool? savedEnabled;
  List<String>? savedCategoryIds;

  @override
  Future<List<LocalNewsSource>> listLocalNewsSources() async => const [];

  @override
  Future<LocalNewsSettings> updateLocalNewsSettings(
    String communityId, {
    required bool enabled,
    required List<String> sourceIds,
    required List<String> categoryIds,
    required String language,
    required String approvalMode,
  }) async {
    savedEnabled = enabled;
    savedCategoryIds = categoryIds;
    return super.updateLocalNewsSettings(
      communityId,
      enabled: enabled,
      sourceIds: sourceIds,
      categoryIds: categoryIds,
      language: language,
      approvalMode: approvalMode,
    );
  }
}

Community _community({CommunityRole role = CommunityRole.admin}) => Community(
  id: 'town-x-community',
  name: 'Denia',
  description: '',
  town: const Town(id: 'town-1', name: 'Dénia', countryCode: 'ES'),
  visibility: CommunityVisibility.public,
  createdBy: 'owner',
  createdAt: DateTime.utc(2026),
  myRole: role,
  canManageLocalNews: true,
);

Future<void> _pump(
  WidgetTester tester,
  DemoCommunityRepository repository, {
  String language = 'en',
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (_, child) => AppLanguageScope(
        languageCode: language,
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

String _localTime(DateTime value) => const DefaultMaterialLocalizations()
    .formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()));

void main() {
  testWidgets(
    'pilot access is distinct from missing sources and inactive settings still save',
    (tester) async {
      final repository = _NoSourcesRepository();
      await _pump(tester, repository);
      expect(find.text('Pilot access active'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Refresh approved sources'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'No news sources are configured yet. Refresh sources to check again.',
        ),
        findsWidgets,
      );
      expect(
        find.text(
          'Wicchu must approve a news source before automated news can be enabled.',
        ),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Enable automated news'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enable automated news'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      expect(find.byType(SnackBar), findsNothing);
      await tester.scrollUntilVisible(
        find.text('General'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('General'));
      await tester.scrollUntilVisible(
        find.text('Save settings'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Save settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(repository.savedEnabled, false);
      expect(repository.savedCategoryIds, isNotEmpty);
    },
  );
  testWidgets('scheduled dashboard sits above settings with local times', (
    tester,
  ) async {
    final repository = _DashboardRepository(_dashboard());
    await _pump(tester, repository);

    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text('Next review not available'), findsNothing);
    expect(find.textContaining(_localTime(_next)), findsOneWidget);
    expect(find.text('Not run yet'), findsOneWidget);
    expect(find.text('0 of 1'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.text('Next review scheduled'), findsOneWidget);
    expect(find.text('Manual approval'), findsOneWidget);
    expect(
      find.textContaining('a review does not always produce a post'),
      findsOneWidget,
      reason: 'empty state explains that a review is not a publication',
    );
    expect(
      find.textContaining('resets at ${_localTime(_reset)} (00:00 UTC)'),
      findsOneWidget,
    );
    expect(find.textContaining('Review pending news'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Next review')).dy,
      lessThan(tester.getTopLeft(find.text('Enable automated news')).dy),
    );
  });

  testWidgets('pending news shows the review action and refreshes after it', (
    tester,
  ) async {
    final repository = _DashboardRepository(
      _dashboard(status: 'awaiting_approval', pendingApproval: 2, todayUsed: 1),
    );
    await _pump(tester, repository);

    expect(find.text('Awaiting approval'), findsNWidgets(2)); // title and row
    expect(
      find.textContaining('1 waiting for approval already count'),
      findsOneWidget,
    );
    final loads = repository.settingsLoads;
    await tester.tap(find.text('Review pending news (2)'));
    await tester.pumpAndSettle();
    expect(find.byType(PendingPostsPage), findsOneWidget);

    repository.dashboard = _dashboard(publishedToday: 1, todayUsed: 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.settingsLoads, greaterThan(loads));
    expect(find.textContaining('Review pending news'), findsNothing);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(
      find.textContaining('a review does not always produce a post'),
      findsNothing,
    );
  });

  testWidgets('daily limit, missing schedule and errors are explained', (
    tester,
  ) async {
    final repository = _DashboardRepository(
      _dashboard(
        status: 'daily_limit_reached',
        todayUsed: 1,
        publishedToday: 1,
        noNext: true,
      ),
    );
    await _pump(tester, repository);
    expect(find.text('Daily limit reached'), findsOneWidget);
    expect(find.text('Next review not available'), findsOneWidget);

    repository.dashboard = _dashboard(
      status: 'error',
      reason: 'sources_unavailable',
      lastRun: LocalNewsLastRun(
        status: 'error',
        errorReason: 'sources_unavailable',
        finishedAt: DateTime.utc(2026, 10, 19, 20, 17),
      ),
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Something needs attention'), findsOneWidget);
    expect(
      find.text('The selected news sources could not be read.'),
      findsOneWidget,
    );
    expect(find.textContaining('Failed ·'), findsOneWidget);

    repository.dashboard = _dashboard(
      status: 'configuration_needed',
      reason: 'missing_sources',
      noNext: true,
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Configuration needed'), findsOneWidget);
    expect(find.text('Select at least one approved source.'), findsOneWidget);

    repository.dashboard = _dashboard(
      status: 'paused',
      reason: 'disabled',
      enabled: false,
      noNext: true,
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Disabled'), findsOneWidget);
    expect(find.text('Automated news is turned off.'), findsOneWidget);
  });

  testWidgets('Spanish status texts', (tester) async {
    final repository = _DashboardRepository(
      _dashboard(
        status: 'daily_limit_reached',
        todayUsed: 1,
        publishedToday: 1,
        noNext: true,
      ),
    );
    await _pump(tester, repository, language: 'es');
    expect(find.text('Noticias automáticas'), findsWidgets);
    expect(find.text('Límite diario alcanzado'), findsOneWidget);
    expect(find.text('Próxima revisión no disponible'), findsOneWidget);
    expect(find.text('Aún no se ha ejecutado'), findsOneWidget);
    expect(find.text('Esperando aprobación'), findsOneWidget);
    expect(find.text('Actividad reciente'), findsOneWidget);
    expect(find.text('Pendiente de programación'), findsOneWidget);
  });

  testWidgets('dashboard refreshes after settings changes and collection', (
    tester,
  ) async {
    final repository = _DashboardRepository(_dashboard());
    await _pump(tester, repository);
    var loads = repository.settingsLoads;

    await tester.scrollUntilVisible(
      find.text('Check for news now'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Check for news now'));
    await tester.pumpAndSettle();
    expect(repository.settingsLoads, greaterThan(loads));

    // Turn it off so the demo settings (no sources selected) can be saved.
    loads = repository.settingsLoads;
    await tester.scrollUntilVisible(
      find.text('Enable automated news'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enable automated news'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save settings'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(repository.settingsLoads, greaterThan(loads));
  });

  testWidgets('communities without access see no dashboard', (tester) async {
    final repository = _DashboardRepository(_dashboard(), forbidden: true);
    await _pump(tester, repository);
    expect(
      find.text('Automated news is not available for this community.'),
      findsOneWidget,
    );
    expect(find.text('Next review'), findsNothing);
    expect(find.text('Save settings'), findsNothing);
  });
}
