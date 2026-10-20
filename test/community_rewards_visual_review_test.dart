import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:wicchu/features/admin/community_rewards_page.dart';
import 'package:wicchu/features/admin/platform_moderation_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

const _tier = CommunityRewardTier(
  id: 'high_impact',
  monthlyRewardCents: 5000,
  memberTarget: 400,
  monthlyActiveTarget: 150,
  postsTarget: 40,
  interactionsTarget: 150,
  contributorsTarget: 30,
  retentionTargetPercent: 25,
  qualified: false,
);

class _VisualRewardsRepository extends DemoCommunityRepository {
  CommunityInsights insights = const CommunityInsights();

  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      insights;

  @override
  Future<List<CommunityRewardRequest>> listCommunityRewardRequests() async => [
    CommunityRewardRequest(
      id: 'request',
      communityId: 'community',
      countryCode: 'EC',
      contactEmail: 'comunidad@example.com',
      requestedAt: DateTime.utc(2026, 10, 14),
      note: 'Queremos apoyar actividades y proyectos para nuestros vecinos.',
    ),
  ];

  @override
  Future<List<PlatformRewardPayout>> listPlatformRewardPayouts({
    bool completed = false,
  }) async => [
    PlatformRewardPayout(
      id: 'payout',
      communityName: 'Echeandía',
      contactEmail: 'comunidad@example.com',
      periodStart: DateTime.utc(2026, 9),
      rewardCents: 5000,
      currency: 'USD',
      status: 'pending_review',
      availableBalanceCents: 6500,
      attributedJoins: 48,
      attributedNewUsers: 31,
      attributedActive7d: 24,
      attributedActive30d: 18,
    ),
  ];

  @override
  Future<PlatformAnalytics> getPlatformAnalytics() async =>
      const PlatformAnalytics(
        registeredUsers: 1240,
        newRegistrations: 138,
        dailyActiveUsers: 420,
        weeklyActiveUsers: 780,
        monthlyActiveUsers: 1040,
        monthlyRetentionPercent: 62.5,
        activeCommunities: 18,
        participatingCommunities: 7,
        pendingReviews: 2,
        registrationsByLocation: [
          PlatformLocationRegistration(location: 'Ecuador', users: 740),
          PlatformLocationRegistration(location: 'España', users: 500),
        ],
        currencySummary: [
          PlatformCurrencySummary(
            currency: 'USD',
            pendingCents: 12500,
            approvedCents: 8500,
            paidCents: 20000,
            remainingBudgetCents: 300000,
          ),
        ],
        communityPerformance: [
          PlatformCommunityPerformance(
            name: 'Echeandía',
            currency: 'USD',
            members: 420,
            monthlyActive: 180,
            posts: 48,
            interactions: 260,
            contributors: 42,
            newUsers: 31,
            activeAfter7Days: 24,
            activeAfter30Days: 18,
          ),
        ],
      );
}

CommunityInsights _insights({
  required bool requested,
  required String status,
  required bool accepted,
  bool eligible = false,
  String? reviewNote,
}) => CommunityInsights(
  totalMembers: 320,
  monthlyActiveUsers: 120,
  posts30d: 35,
  interactions30d: 142,
  uniqueContributors30d: 27,
  monthlyRetentionRate: 28,
  retentionDataAvailable: true,
  monetization: CommunityMonetizationEligibility(
    eligible: eligible,
    currency: 'USD',
    daysRemaining: 12,
    availableBalanceCents: 1850,
    minimumPayoutCents: 2500,
    payoutSetupComplete: false,
    enrollment: CommunityRewardEnrollment(
      requested: requested,
      status: status,
      accepted: accepted,
      countryCode: 'EC',
      contactEmail: 'comunidad@example.com',
      reviewNote: reviewNote,
    ),
    nextTier: _tier,
    tiers: const [_tier],
    history: accepted
        ? [
            CommunityRewardEvaluation(
              id: 'history',
              periodStart: DateTime.utc(2026, 9),
              periodEnd: DateTime.utc(2026, 10),
              members: 280,
              monthlyActive: 105,
              posts: 31,
              interactions: 130,
              uniqueContributors: 25,
              retentionPercent: 27,
              tierId: 'growing',
              rewardCents: 2500,
              currency: 'USD',
              status: 'approved',
            ),
          ]
        : const [],
  ),
);

void main() {
  testWidgets('capture every community rewards state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts']) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    final repository = _VisualRewardsRepository();
    final community = (await repository.listJoinedCommunities()).first;
    final boundary = GlobalKey();

    Future<void> open(
      Widget page, {
      bool light = false,
      double textScale = 1,
    }) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: light ? WicchuTheme.light : WicchuTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> shot(String name) async {
      await tester.pump();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('/tmp/wicchu-rewards-review');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    repository.insights = _insights(
      requested: false,
      status: 'not_requested',
      accepted: false,
    );
    await open(
      CommunityRewardsPage(community: community, repository: repository),
    );
    await shot('00-roadmap');
    await tester.tap(find.byKey(const ValueKey('reward-objectives-action')));
    await tester.pumpAndSettle();
    await shot('00b-objectives');
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    await open(
      CommunityRewardsPage(community: community, repository: repository),
      textScale: 1.3,
    );
    await shot('00c-roadmap-large-text');
    await open(
      CommunityRewardsPage(community: community, repository: repository),
      light: true,
    );
    await shot('00d-roadmap-light');
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await open(
      CommunityRewardsPage(community: community, repository: repository),
    );
    await shot('00e-roadmap-small-phone');
    await tester.binding.setSurfaceSize(const Size(390, 844));

    repository.insights = _insights(
      requested: false,
      status: 'not_requested',
      accepted: false,
      eligible: true,
    );
    await open(
      CommunityRewardsPage(community: community, repository: repository),
    );
    await shot('01-request');

    repository.insights = _insights(
      requested: true,
      status: 'rejected',
      accepted: false,
      reviewNote: 'Verifica el correo de contacto antes de volver a enviarla.',
    );
    await open(
      CommunityRewardsPage(community: community, repository: repository),
    );
    await shot('01b-rejected');

    repository.insights = _insights(
      requested: true,
      status: 'pending',
      accepted: false,
    );
    await open(
      CommunityRewardsPage(community: community, repository: repository),
    );
    await shot('02-pending');

    repository.insights = _insights(
      requested: true,
      status: 'approved',
      accepted: false,
    );
    await open(
      CommunityRewardsPage(community: community, repository: repository),
    );
    await shot('03-terms');

    repository.insights = _insights(
      requested: true,
      status: 'approved',
      accepted: true,
    );
    await open(
      CommunityRewardsPage(community: community, repository: repository),
    );
    await shot('04-dashboard');
    await tester.scrollUntilVisible(
      find.text('Requisitos y pago'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await shot('05-dashboard-details');

    await open(
      AdminDashboardPage(community: community, repository: repository),
    );
    await shot('06-admin-entry');

    await open(PlatformModerationPage(repository: repository));
    await tester.ensureVisible(find.text('Recompensas'));
    await tester.tap(find.text('Recompensas'));
    await tester.pumpAndSettle();
    await shot('07-platform-requests');
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    await shot('07b-request-approval');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pagos'));
    await tester.tap(find.text('Pagos'));
    await tester.pumpAndSettle();
    await shot('08-platform-payouts');
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    await shot('08b-payout-confirmation');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Analítica'));
    await tester.tap(find.text('Analítica'));
    await tester.pumpAndSettle();
    await shot('09-platform-analytics');

    await open(
      CommunityRewardsPage(community: community, repository: repository),
      light: true,
    );
    await shot('10-light-dashboard');

    repository.insights = _insights(
      requested: true,
      status: 'approved',
      accepted: false,
    );
    await open(
      CommunityRewardsPage(community: community, repository: repository),
      textScale: 1.3,
    );
    await shot('11-large-text-terms');

    await open(
      PlatformModerationPage(repository: repository, initialTab: 3),
      textScale: 1.3,
    );
    await shot('12-large-text-payout');
  });
}
