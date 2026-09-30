import 'package:flutter/material.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
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

class _UnavailableInsightsRepository extends DemoCommunityRepository {
  @override
  Future<CommunityInsights> getCommunityInsights(String communityId) async =>
      throw const ApiException('Not found', statusCode: 404);
}

void main() {
  testWidgets('missing insights does not show fabricated metrics', (
    tester,
  ) async {
    final repository = _UnavailableInsightsRepository();
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
    expect(
      find.text('Community statistics are not available yet.'),
      findsOneWidget,
    );
    expect(find.text('Monthly active'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('insights fits a narrow screen with large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _InsightsRepository();
    final community = (await repository.listJoinedCommunities()).first;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: CommunityInsightsPage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tip'), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('2,043'), findsNWidgets(2));
    expect(find.text('527'), findsOneWidget);
    expect(find.text('248'), findsOneWidget);
    expect(find.text('25.8%'), findsOneWidget);
    expect(find.text('Member growth'), findsOneWidget);
    expect(find.text('1,204'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
