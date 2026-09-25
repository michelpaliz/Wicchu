import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/managed_communities_page.dart';

class _Repository extends DemoCommunityRepository {
  bool fail = true;
  @override
  Future<List<Community>> listManagedCommunities() async => [
    (await listJoinedCommunities()).first,
  ];
  @override
  Future<AdminAttentionSummary> getAdminAttention(String communityId) async {
    if (fail) throw Exception('Unavailable');
    return const AdminAttentionSummary(openReports: 2);
  }
}

void main() {
  testWidgets(
    'managed community status never treats a failed request as caught up',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: ManagedCommunitiesPage(
            repository: repository,
            onCommunityCreated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('All caught up'), findsNothing);
      expect(find.text('Retry status'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text('Retry status'));
      await tester.pumpAndSettle();
      expect(find.text('2 pending actions'), findsOneWidget);
      expect(find.text('All caught up'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Tip'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
