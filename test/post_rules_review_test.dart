import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_rules_review_page.dart';

class _RulesRepository extends DemoCommunityRepository {
  bool failAcceptance = true;
  int? acceptedVersion;
  @override
  Future<CommunityRules> listRules(String communityId) async =>
      const CommunityRules(
        rules: [
          CommunityRule(
            title: 'Be respectful',
            description: 'Respect your neighbors.',
          ),
        ],
        rulesVersion: 3,
        acceptedRulesVersion: 0,
        acceptanceRequired: true,
        canManage: false,
      );
  @override
  Future<void> acceptRules(String communityId, int rulesVersion) async {
    if (failAcceptance) throw Exception('Unable to save agreement');
    acceptedVersion = rulesVersion;
  }
}

void main() {
  testWidgets(
    'failed acceptance stays on review; successful acceptance returns true',
    (tester) async {
      final repository = _RulesRepository();
      final community = (await repository.listCommunities()).first;
      bool? agreed;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  agreed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostRulesReviewPage(
                        community: community,
                        repository: repository,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Respect your neighbors.'), findsOneWidget);
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(agreed, isNull);
      expect(find.byType(PostRulesReviewPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    repository.failAcceptance = false;
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(agreed, isTrue);
      expect(repository.acceptedVersion, 3);
      expect(find.byType(PostRulesReviewPage), findsNothing);
    },
  );
}
