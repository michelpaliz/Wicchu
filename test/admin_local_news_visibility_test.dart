import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:wicchu/localization/app_language.dart';

Community _community(
  String id, {
  required CommunityRole role,
  required bool canManageLocalNews,
}) => Community(
  id: id,
  name: id,
  description: '',
  town: const Town(id: 'town-1', name: 'Town X', countryCode: 'ES'),
  visibility: CommunityVisibility.public,
  createdBy: 'owner',
  createdAt: DateTime.utc(2026),
  myRole: role,
  canManageLocalNews: canManageLocalNews,
);

Future<void> _show(
  WidgetTester tester,
  DemoCommunityRepository repository,
  Community community,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppLanguageScope(
      languageCode: 'en',
      onLanguageChanged: (_) {},
      child: MaterialApp(
        home: AdminDashboardPage(community: community, repository: repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // "Rules" is the row right after Automated news, so once it is built the news row would be too.
  await tester.scrollUntilVisible(
    find.text('Rules'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  final repository = DemoCommunityRepository();

  testWidgets('pilot administrators see Automated news', (tester) async {
    await _show(
      tester,
      repository,
      _community('pilot', role: CommunityRole.admin, canManageLocalNews: true),
    );
    expect(find.text('Automated news'), findsOneWidget);
  });

  testWidgets('pilot owners see Automated news', (tester) async {
    await _show(
      tester,
      repository,
      _community('pilot', role: CommunityRole.owner, canManageLocalNews: true),
    );
    expect(find.text('Automated news'), findsOneWidget);
  });

  testWidgets('non-pilot administrators do not see it', (tester) async {
    await _show(
      tester,
      repository,
      _community('other', role: CommunityRole.owner, canManageLocalNews: false),
    );
    expect(find.text('Automated news'), findsNothing);
  });

  testWidgets('moderators of a pilot community do not see it', (tester) async {
    await _show(
      tester,
      repository,
      _community(
        'pilot',
        role: CommunityRole.moderator,
        canManageLocalNews: false,
      ),
    );
    expect(find.text('Automated news'), findsNothing);
  });

  testWidgets('visibility follows the community when switching', (
    tester,
  ) async {
    await _show(
      tester,
      repository,
      _community('pilot', role: CommunityRole.admin, canManageLocalNews: true),
    );
    expect(find.text('Automated news'), findsOneWidget);

    await _show(
      tester,
      repository,
      _community('other', role: CommunityRole.admin, canManageLocalNews: false),
    );
    expect(find.text('Automated news'), findsNothing);

    await _show(
      tester,
      repository,
      _community('pilot', role: CommunityRole.admin, canManageLocalNews: true),
    );
    expect(find.text('Automated news'), findsOneWidget);
  });
}
