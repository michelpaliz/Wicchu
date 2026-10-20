import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:wicchu/features/admin/community_rewards_page.dart';
import 'package:wicchu/features/admin/platform_moderation_page.dart';

const _highImpact = CommunityRewardTier(
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

const _tierMissingContributorTarget = CommunityRewardTier(
  id: 'legacy',
  monthlyRewardCents: 5000,
  memberTarget: 400,
  monthlyActiveTarget: 150,
  postsTarget: 40,
  interactionsTarget: 150,
  retentionTargetPercent: 25,
  qualified: false,
);

class _RewardsRepository extends DemoCommunityRepository {
  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      CommunityInsights(
        totalMembers: 320,
        monthlyActiveUsers: 120,
        posts30d: 35,
        interactions30d: 142,
        uniqueContributors30d: 27,
        monthlyRetentionRate: 28,
        monetization: CommunityMonetizationEligibility(
          daysRemaining: 12,
          enrollment: CommunityRewardEnrollment(
            requested: true,
            status: 'approved',
            accepted: true,
            countryCode: 'ES',
            currency: 'EUR',
          ),
          nextTier: _highImpact,
          tiers: const [_highImpact],
          history: [
            CommunityRewardEvaluation(
              id: 'reward-1',
              periodStart: DateTime.utc(2026, 9),
              periodEnd: DateTime.utc(2026, 10),
              members: 280,
              monthlyActive: 105,
              posts: 31,
              interactions: 130,
              retentionPercent: 27,
              tierId: 'growing',
              rewardCents: 2500,
              currency: 'EUR',
              status: 'approved',
            ),
          ],
        ),
      );
}

class _EnrollmentRepository extends DemoCommunityRepository {
  bool accepted = false;

  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      CommunityInsights(
        monetization: CommunityMonetizationEligibility(
          enrollment: CommunityRewardEnrollment(
            requested: true,
            status: 'approved',
            accepted: accepted,
            countryCode: 'EC',
            currency: 'USD',
          ),
        ),
      );

  @override
  Future<CommunityRewardEnrollment> acceptCommunityRewardTerms(
    String communityId, {
    required String countryCode,
  }) async {
    accepted = true;
    return CommunityRewardEnrollment(
      accepted: true,
      countryCode: countryCode,
      currency: countryCode == 'EC' ? 'USD' : 'EUR',
    );
  }
}

class _RequestRepository extends DemoCommunityRepository {
  CommunityRewardEnrollment enrollment = const CommunityRewardEnrollment();
  String? submittedEmail;

  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      CommunityInsights(
        monetization: CommunityMonetizationEligibility(
          eligible: true,
          enrollment: enrollment,
        ),
      );

  @override
  Future<CommunityRewardEnrollment> requestCommunityRewards(
    String communityId, {
    required String countryCode,
    String? countryName,
    required String contactEmail,
    String? note,
  }) async {
    submittedEmail = contactEmail;
    enrollment = CommunityRewardEnrollment(
      requested: true,
      status: 'pending',
      countryCode: countryCode,
      countryName: countryName,
      contactEmail: contactEmail,
    );
    return enrollment;
  }
}

class _RoadmapRepository extends DemoCommunityRepository {
  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      const CommunityInsights(
        totalMembers: 120,
        monthlyActiveUsers: 38,
        posts30d: 12,
        interactions30d: 44,
        uniqueContributors30d: 9,
        monthlyRetentionRate: 18,
        retentionDataAvailable: true,
        monetization: CommunityMonetizationEligibility(
          eligible: false,
          nextTier: _highImpact,
          tiers: [_highImpact],
        ),
      );
}

class _IncompleteRoadmapRepository extends DemoCommunityRepository {
  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      const CommunityInsights(
        totalMembers: 120,
        monthlyActiveUsers: 38,
        posts30d: 12,
        interactions30d: 44,
        uniqueContributors30d: 9,
        monetization: CommunityMonetizationEligibility(
          nextTier: _tierMissingContributorTarget,
          tiers: [_tierMissingContributorTarget],
        ),
      );
}

class _RejectedRequestRepository extends _RequestRepository {
  _RejectedRequestRepository() {
    enrollment = const CommunityRewardEnrollment(
      requested: true,
      status: 'rejected',
      countryCode: 'EC',
      contactEmail: 'owner@example.com',
      reviewNote: 'Necesitamos verificar la dirección de contacto.',
    );
  }
}

class _ModerationRepository extends DemoCommunityRepository {
  bool requestApproved = false;
  String payoutStatus = 'pending_review';
  final List<String> payoutActions = [];

  @override
  Future<List<CommunityRewardRequest>> listCommunityRewardRequests() async => [
    CommunityRewardRequest(
      id: 'request-1',
      communityId: 'community-1',
      countryCode: 'EC',
      contactEmail: 'owner@example.com',
      requestedAt: DateTime.utc(2026, 10, 15),
    ),
  ];

  @override
  Future<void> reviewCommunityRewardRequest(
    String requestId, {
    required bool approve,
    String currency = 'USD',
    String? note,
  }) async {
    requestApproved = approve;
  }

  @override
  Future<List<PlatformRewardPayout>> listPlatformRewardPayouts({
    bool completed = false,
  }) async => [
    PlatformRewardPayout(
      id: 'payout-1',
      communityName: 'Echeandía',
      contactEmail: 'owner@example.com',
      periodStart: DateTime.utc(2026, 9),
      rewardCents: 5000,
      currency: 'USD',
      status: payoutStatus,
      availableBalanceCents: 6500,
    ),
  ];

  @override
  Future<void> reviewPlatformRewardPayout(
    String payoutId, {
    required String action,
    String? note,
  }) async {
    payoutActions.add(action);
    if (action == 'approve') payoutStatus = 'approved';
  }
}

void main() {
  testWidgets('roadmap is visible before the rewards application unlocks', (
    tester,
  ) async {
    final repository = _RoadmapRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRewardsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your rewards journey'), findsNothing);
    expect(find.text(community.name), findsOneWidget);
    expect(find.text('Stage 1 of 4 · Active community'), findsOneWidget);
    expect(find.text('Build an active community'), findsNothing);
    expect(find.text('0 of 5 requirements completed'), findsNothing);
    expect(find.text('29%'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Request access'), findsOneWidget);
    expect(find.text('Monthly rewards'), findsOneWidget);
    expect(find.text('Send request'), findsNothing);
    expect(
      find.byKey(const ValueKey('reward-objectives-action')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reward-objectives-action')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Build an active community'), findsOneWidget);
    expect(find.text('0 of 5 requirements completed'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Monthly active members'), findsOneWidget);
    expect(find.text('Useful posts in 30 days'), findsOneWidget);
    expect(find.text('Meaningful interactions in 30 days'), findsOneWidget);
    expect(find.text('Unique contributors in 30 days'), findsOneWidget);
    expect(find.text('Monthly member retention'), findsNothing);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wicchu review'));
    await tester.pumpAndSettle();
    expect(find.text('Review and accept terms'), findsOneWidget);
    expect(
      find.text('Complete the previous stage to continue.'),
      findsOneWidget,
    );
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(
        'Complete stage 1 to unlock the application. Eligibility and monthly rewards still require Wicchu review and are not guaranteed.',
      ),
      250,
    );
    expect(
      find.text(
        'Complete stage 1 to unlock the application. Eligibility and monthly rewards still require Wicchu review and are not guaranteed.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'admin dashboard opens roadmap on a small screen (dark: $dark)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _RoadmapRepository();
        final community = (await repository.listJoinedCommunities()).first;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: AdminDashboardPage(
              community: community,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('Rewards roadmap'), 300);
        expect(find.text('REWARDS'), findsOneWidget);
        expect(find.text('Stage 1 of 4 · 29% completed'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Your rewards roadmap'), findsNothing);
        expect(find.text('View roadmap'), findsNothing);
        expect(find.text('Request access'), findsNothing);
        await tester.tap(find.text('Rewards roadmap'));
        await tester.pumpAndSettle();
        expect(find.text('Stage 1 of 4 · Active community'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reward dashboard describes the current period accurately', (
    tester,
  ) async {
    final repository = _RewardsRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRewardsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No reward unlocked for this evaluation period yet'),
      findsOneWidget,
    );
    expect(find.text('No reward unlocked yet'), findsNothing);
    expect(find.text('Approved balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enrolled admin row uses the same five roadmap objectives', (
    tester,
  ) async {
    final repository = _RewardsRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardPage(community: community, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Rewards roadmap'), 300);
    expect(find.text('86% completed'), findsOneWidget);
    expect(find.text('View my progress'), findsNothing);
    expect(find.textContaining('/6'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('roadmap does not mark an unconfigured target as complete', (
    tester,
  ) async {
    final repository = _IncompleteRoadmapRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRewardsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reward-objectives-action')));
    await tester.pumpAndSettle();
    expect(find.text('Pending setup'), findsOneWidget);
    expect(find.text('9/0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moderator reviews requests and confirms payout actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ModerationRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformModerationPage(repository: repository, initialTab: 2),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Reject'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Missing verification');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Reject'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();
    expect(repository.requestApproved, isTrue);

    await tester.ensureVisible(find.text('Payouts'));
    await tester.tap(find.text('Payouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(repository.payoutActions, isEmpty);
    expect(find.text('Confirm \$50.00 for Echeandía.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(repository.payoutActions, ['approve']);

    await tester.tap(find.widgetWithText(FilledButton, 'Mark paid'));
    await tester.pumpAndSettle();
    expect(find.text('Mark payout as paid'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(repository.payoutActions, ['approve', 'mark_paid']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner validates and submits a rewards request', (tester) async {
    final repository = _RequestRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRewardsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send request'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'owner@example.com',
    );
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(repository.submittedEmail, 'owner@example.com');
    expect(find.text('Request under review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected request preserves details for resubmission', (
    tester,
  ) async {
    final repository = _RejectedRequestRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRewardsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ecuador'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Why it was not approved'), findsOneWidget);
    expect(
      find.text('Necesitamos verificar la dirección de contacto.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved owner accepts the pilot terms', (tester) async {
    final repository = _EnrollmentRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRewardsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Join the Community Rewards pilot'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 250);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Accept and join pilot'), 200);
    await tester.tap(find.text('Accept and join pilot'));
    await tester.pumpAndSettle();
    expect(repository.accepted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward details explain metrics and monthly history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _RewardsRepository();
    final community = (await repository.listJoinedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRewardsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('12 days remaining'), findsOneWidget);
    expect(find.text('320 / 400'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Previous monthly results'), 300);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('25 €'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
