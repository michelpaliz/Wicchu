import 'dart:async';

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
  _NoSourcesRepository()
    : super(
        _dashboard(
          status: 'configuration_needed',
          reason: 'missing_sources',
          enabled: false,
          noNext: true,
        ),
      );

  bool? savedEnabled;
  List<String>? savedCategoryIds;

  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async =>
      LocalNewsSettings(
        enabled: savedEnabled ?? false,
        categoryIds: savedCategoryIds ?? const [],
        access: const LocalNewsAccess(
          entitled: true,
          source: 'pilot',
          tier: 'pilot',
          monthlyLimit: 60,
        ),
        dashboard: _dashboard(
          status: 'configuration_needed',
          reason: 'missing_sources',
          enabled: savedEnabled ?? false,
          noNext: true,
        ),
      );

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

class _RacingSourcesRepository extends _NoSourcesRepository {
  final olderRefresh = Completer<List<LocalNewsSource>>();
  var sourceLoads = 0;

  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async =>
      const LocalNewsSettings(
        access: LocalNewsAccess(
          entitled: true,
          source: 'subscription',
          tier: 'pro',
          monthlyLimit: 60,
        ),
      );

  @override
  Future<List<LocalNewsSource>> listLocalNewsSources() async {
    sourceLoads += 1;
    if (sourceLoads == 1) return const [];
    if (sourceLoads == 2) return olderRefresh.future;
    return const [
      LocalNewsSource(
        id: 'new-source',
        name: 'New approved source',
        type: 'rss',
        trusted: true,
        authorizedForAutoPublish: true,
      ),
    ];
  }
}

class _PendingNewsRepository extends DemoCommunityRepository {
  final pending = Completer<LocalNewsSettings>();
  int saves = 0;
  LocalNewsSettings? saved;

  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String id) async =>
      saved ??
      LocalNewsSettings(
        enabled: true,
        sourceIds: const ['source-1'],
        categoryIds: [(await listCategories(id)).first.id],
        subscriptionTier: 'pro',
        monthlyLimit: 60,
      );

  @override
  Future<LocalNewsSettings> updateLocalNewsSettings(
    String id, {
    required bool enabled,
    required List<String> sourceIds,
    required List<String> categoryIds,
    required String language,
    required String approvalMode,
  }) async {
    saves++;
    return saved = await pending.future;
  }
}

class _RefreshingNewsRepository extends DemoCommunityRepository {
  int loads = 0;
  int runs = 0;
  bool stale = false;
  final refresh = Completer<LocalNewsSettings>();

  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String id) async {
    loads++;
    if (loads == 2 && !stale) return refresh.future;
    return LocalNewsSettings(
      enabled: true,
      sourceIds: [
        stale ? 'removed-source' : (await listLocalNewsSources()).first.id,
      ],
      categoryIds: [
        stale ? 'removed-category' : (await listCategories(id)).first.id,
      ],
      subscriptionTier: 'pro',
      monthlyLimit: 60,
    );
  }

  @override
  Future<LocalNewsRunResult> runLocalNewsNow(String id) async {
    runs++;
    return const LocalNewsRunResult(processed: 1);
  }
}

class _SourceTrustRepository extends DemoCommunityRepository {
  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async =>
      const LocalNewsSettings(
        access: LocalNewsAccess(
          entitled: true,
          source: 'subscription',
          tier: 'pro',
          monthlyLimit: 60,
        ),
      );

  @override
  Future<List<LocalNewsSource>> listLocalNewsSources() async => [
    for (final trusted in [false, true])
      for (final authorized in [false, true])
        LocalNewsSource(
          id: '$trusted-$authorized',
          name: '$trusted-$authorized',
          type: 'rss',
          trusted: trusted,
          authorizedForAutoPublish: authorized,
        ),
  ];
}

class _AssignedPilotSourceRepository extends DemoCommunityRepository {
  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async =>
      const LocalNewsSettings(
        sourceIds: ['source-1'],
        access: LocalNewsAccess(
          entitled: true,
          source: 'pilot',
          tier: 'pilot',
          monthlyLimit: 60,
        ),
      );
}

class _NoDashboardRepository extends DemoCommunityRepository {
  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async =>
      const LocalNewsSettings(
        enabled: false,
        subscriptionTier: 'pro',
        monthlyLimit: 60,
        access: LocalNewsAccess(
          entitled: true,
          source: 'plan',
          tier: 'pro',
          monthlyLimit: 60,
        ),
      );
}

class _RestrictedRepository extends DemoCommunityRepository {
  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async =>
      LocalNewsSettings(
        enabled: false,
        subscriptionTier: 'none',
        monthlyLimit: 0,
        access: const LocalNewsAccess(
          entitled: false,
          source: 'none',
          tier: 'none',
          monthlyLimit: 0,
        ),
        dashboard: _dashboard(status: 'paused', enabled: false),
      );
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

Future<void> _expand(WidgetTester tester, String title) async {
  final label = find.text(title).first;
  for (var attempt = 0; attempt < 8 && label.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  expect(label, findsOneWidget);
  await tester.ensureVisible(label);
  await tester.pumpAndSettle();
  await tester.tap(label);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'pilot hides source controls but keeps language and manual review',
    (tester) async {
      await _pump(tester, _AssignedPilotSourceRepository());
      expect(find.text('Enable automated news'), findsOneWidget);
      expect(find.text('Approved sources'), findsNothing);
      expect(
        find.text(
          'Wicchu assigns verified news sources based on your community. No RSS link is needed.',
        ),
        findsOneWidget,
      );
      expect(find.text('News language'), findsOneWidget);
      expect(find.text('Approval mode'), findsOneWidget);
      await _expand(tester, 'News categories');
      expect(find.widgetWithText(FilterChip, 'General'), findsOneWidget);
    },
  );

  testWidgets('pilot can opt in while Wicchu prepares approved sources', (
    tester,
  ) async {
    final repository = _NoSourcesRepository();
    await _pump(tester, repository);
    expect(find.text('Pilot access active'), findsOneWidget);

    expect(find.text('Approved sources'), findsNothing);
    expect(
      find.text(
        'News sources are unavailable for this community. Wicchu assigns verified sources automatically.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
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
      isFalse,
    );
    expect(find.byType(SnackBar), findsNothing);

    await _expand(tester, 'News categories');
    await tester.ensureVisible(find.text('General'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'General'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enable automated news'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enable automated news'));
    await tester.pumpAndSettle();

    expect(repository.savedEnabled, isTrue);
    expect(repository.savedCategoryIds, isNotEmpty);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('older refresh cannot replace newer approved sources', (
    tester,
  ) async {
    final repository = _RacingSourcesRepository();
    await _pump(tester, repository);

    await _expand(tester, 'Approved sources');
    final refresh = find.text('Refresh approved sources');
    await tester.scrollUntilVisible(
      refresh,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    final refreshButton = find.widgetWithText(
      TextButton,
      'Refresh approved sources',
    );
    await tester.tap(refreshButton);
    await tester.pump();
    await tester.tap(refreshButton);
    await tester.pump();

    expect(find.text('New approved source'), findsOneWidget);
    repository.olderRefresh.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('New approved source'), findsOneWidget);
    expect(find.text('Refresh approved sources'), findsNothing);
  });

  testWidgets('scheduled dashboard sits above settings with local times', (
    tester,
  ) async {
    final repository = _DashboardRepository(_dashboard());
    await _pump(tester, repository);

    expect(find.text('Scheduled'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.text('Next news check not available'), findsNothing);
    expect(find.text('Next publication'), findsOneWidget);
    expect(
      find.text('Not scheduled. The next check may not find a relevant article; publication requires your approval.'),
      findsOneWidget,
    );
    expect(find.textContaining(_localTime(_next)), findsOneWidget);
    expect(find.text('Not run yet'), findsOneWidget);
    expect(find.text('0 of 1'), findsOneWidget);
    expect(find.text('Review before publishing'), findsOneWidget);
    expect(find.text('Pending approvals'), findsOneWidget);
    expect(find.text('Published today'), findsOneWidget);
    expect(find.text('Save settings'), findsNothing);
    expect(
      find.textContaining('resets at ${_localTime(_reset)} (00:00 UTC)'),
      findsOneWidget,
    );
    expect(find.textContaining('Review pending news'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Next news check')).dy,
      greaterThan(tester.getTopLeft(find.text('Enable automated news')).dy),
    );
  });

  testWidgets('unavailable scheduler is explicit and settings remain usable', (
    tester,
  ) async {
    await _pump(tester, _NoDashboardRepository());

    expect(find.text('Scheduler unavailable'), findsOneWidget);
    expect(
      find.text(
        'Scheduling information is temporarily unavailable. Refresh to try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Next news check not available'), findsOneWidget);
    expect(find.text('Not run yet'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
  });

  testWidgets('backend restriction disables activation and explains why', (
    tester,
  ) async {
    await _pump(tester, _RestrictedRepository());

    expect(
      find.text(
        'Local News access must be enabled for this community by Wicchu.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
  });

  testWidgets('pending news shows the review action and refreshes after it', (
    tester,
  ) async {
    final repository = _DashboardRepository(
      _dashboard(status: 'awaiting_approval', pendingApproval: 2, todayUsed: 1),
    );
    await _pump(tester, repository);

    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.text('Pending approvals'), findsOneWidget);
    expect(
      find.text('A news card is awaiting your approval. It will not appear in the community until you approve it.'),
      findsOneWidget,
    );
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
    expect(find.text('Next news check not available'), findsOneWidget);

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
    expect(find.text('Waiting for news sources'), findsOneWidget);
    expect(
      find.text(
        'Wicchu is preparing verified news sources. Collection will start when a source is available.',
      ),
      findsOneWidget,
    );

    repository.dashboard = _dashboard(
      status: 'paused',
      reason: 'disabled',
      enabled: false,
      noNext: true,
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text('Automated news is turned off.'), findsOneWidget);
    expect(
      find.text('Not scheduled while automated news is off.'),
      findsOneWidget,
    );
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
    expect(find.text('Próxima búsqueda no disponible'), findsOneWidget);
    expect(find.text('Próxima publicación'), findsOneWidget);
    expect(find.text('Aún no se ha ejecutado'), findsOneWidget);
    expect(find.text('Pendientes de aprobación'), findsOneWidget);
    expect(find.text('Publicadas hoy'), findsOneWidget);
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

    // Turning it off persists immediately and refreshes the dashboard.
    loads = repository.settingsLoads;
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
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
    expect(find.text('Next news check'), findsNothing);
    expect(find.text('Save settings'), findsNothing);
  });

  testWidgets(
    'automatic publication label requires both trust and authorization',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _SourceTrustRepository();
      final community = await repository.getCommunity('town-x-community');
      await tester.pumpWidget(
        MaterialApp(
          home: LocalNewsSettingsPage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expand(tester, 'Approved sources');
      for (final trusted in [false, true]) {
        for (final authorized in [false, true]) {
          final row = find.widgetWithText(
            CheckboxListTile,
            '$trusted-$authorized',
          );
          await tester.scrollUntilVisible(
            row,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.text(
                trusted && authorized
                    ? 'Trusted for automatic publishing'
                    : 'Review required',
              ),
            ),
            findsOneWidget,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save keeps draft and releases busy state', (
    tester,
  ) async {
    final repository = _PendingNewsRepository();
    final community = await repository.getCommunity('town-x-community');
    await tester.pumpWidget(
      MaterialApp(
        home: LocalNewsSettingsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    repository.pending.completeError(Exception('Save failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Save failed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'news refresh blocks repeated runs and recovers from refresh failure',
    (tester) async {
      final repository = _RefreshingNewsRepository();
      final community = await repository.getCommunity('town-x-community');
      await tester.pumpWidget(
        MaterialApp(
          home: LocalNewsSettingsPage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final run = find.widgetWithText(OutlinedButton, 'Check for news now');
      await tester.scrollUntilVisible(
        run,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(run);
      await tester.pumpAndSettle();
      final action = tester.widget<OutlinedButton>(run).onPressed!;
      await tester.tap(run);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      action();
      await tester.pump();
      expect(repository.runs, 1);
      repository.refresh.completeError(Exception('Refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('News categories'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('News categories'), findsOneWidget);
      expect(repository.loads, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removed news sources and categories cannot pass enabled validation',
    (tester) async {
      final repository = _RefreshingNewsRepository()..stale = true;
      final community = await repository.getCommunity('town-x-community');
      await tester.pumpWidget(
        MaterialApp(
          home: LocalNewsSettingsPage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save settings');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('Select an available approved news source.'),
        findsOneWidget,
      );
      final run = find.widgetWithText(OutlinedButton, 'Check for news now');
      await tester.scrollUntilVisible(
        run,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(run).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsaved news changes block collection and saving blocks conflicting edits',
    (tester) async {
      final repository = _PendingNewsRepository();
      final community = await repository.getCommunity('town-x-community');
      await tester.pumpWidget(
        MaterialApp(
          home: LocalNewsSettingsPage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Save settings'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Check for news now'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Check for news now'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save settings');
      await tester.tap(save);
      await tester.pump();
      expect(repository.saves, 1);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byWidgetPredicate((w) => w is AbsorbPointer && w.absorbing),
            )
            .absorbing,
        isTrue,
      );
      repository.pending.complete(
        const LocalNewsSettings(
          enabled: false,
          subscriptionTier: 'pro',
          monthlyLimit: 60,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save settings'), findsNothing);
      expect(find.text('Check for news now'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh keeps an in-progress draft intact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoCommunityRepository();
    final community = await repository.getCommunity('town-x-community');
    await tester.pumpWidget(
      MaterialApp(
        home: LocalNewsSettingsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _expand(tester, 'News categories');
    final newsCategory = find.widgetWithText(FilterChip, 'News');
    await tester.tap(newsCategory);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(tester.widget<FilterChip>(newsCategory).selected, isTrue);

    // A refresh (dashboard refresh icon) must not discard the draft.
    await tester.tap(find.byTooltip('Refresh').first);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(tester.widget<FilterChip>(newsCategory).selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
