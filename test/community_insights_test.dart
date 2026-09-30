import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/community_insights_page.dart';

class _InsightsRepository extends DemoCommunityRepository {
  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      CommunityInsights(
        totalMembers: 2043,
        newMembers30d: 143,
        newMembersChangePercent: 12.4,
        monthlyActiveUsers: 527,
        weeklyActiveUsers: 248,
        monthlyActivityRate: 25.8,
        posts30d: 84,
        comments30d: 326,
        reactions30d: 1204,
        memberGrowth: [
          MemberGrowthPoint(date: DateTime.utc(2026, 9, 1), members: 1900),
          MemberGrowthPoint(date: DateTime.utc(2026, 9, 30), members: 2043),
        ],
      );
}

void main() {
  testWidgets('insights page presents growth and engagement metrics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _InsightsRepository();
    final community = (await repository.listJoinedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityInsightsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Community Insights'), findsOneWidget);
    expect(find.text('2,043'), findsOneWidget);
    expect(find.text('527'), findsOneWidget);
    expect(find.text('248'), findsOneWidget);
    expect(find.text('25.8%'), findsOneWidget);
    expect(find.text('Member growth'), findsOneWidget);
    expect(find.text('1,204'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
