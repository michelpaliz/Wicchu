import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/community_rewards_page.dart';

const _highImpact = CommunityRewardTier(
  id: 'high_impact',
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

void main() {
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

    expect(find.text('Community rewards'), findsOneWidget);
    expect(find.text('12 days remaining'), findsOneWidget);
    expect(find.text('320 / 400'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Previous monthly results'), 300);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('25 €'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
