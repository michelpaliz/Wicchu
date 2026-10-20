import 'dart:async';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/create_community_page.dart';
import 'package:wicchu/features/main/pages_hub_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

Community page(
  String id, {
  CommunityRole role = CommunityRole.member,
  ProfileCategory category = ProfileCategory.organization,
  CommunityType type = CommunityType.publicProfile,
}) => Community(
  id: id,
  name: id,
  description: '',
  town: const Town(id: 'town-1', name: 'Town', countryCode: 'ES'),
  visibility: CommunityVisibility.public,
  createdBy: 'owner',
  createdAt: DateTime(2026),
  myRole: role,
  type: type,
  profileCategory: category,
);

class HubRepository extends DemoCommunityRepository {
  bool fail = false;
  List<Community> joined = [];
  List<Community> managed = [];
  @override
  Future<List<Community>> listJoinedCommunities() async {
    if (fail) throw Exception('Unable to load pages');
    return joined;
  }

  @override
  Future<List<Community>> listManagedCommunities() async => managed;
}

class _RacingHubRepository extends HubRepository {
  final requests = <Completer<List<Community>>>[];
  bool delay = false;
  @override
  Future<List<Community>> listJoinedCommunities() {
    if (!delay) return Future.value(joined);
    final request = Completer<List<Community>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<Community> getCommunity(String id) async => joined.first;
}

void main() {
  testWidgets('older page refresh cannot clear a newer selected page', (
    tester,
  ) async {
    final repository = _RacingHubRepository()
      ..joined = [page('Selected', role: CommunityRole.owner)];
    final key = GlobalKey<PagesHubPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: PagesHubPage(key: key, repository: repository, onChanged: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected'));
    await tester.pumpAndSettle();
    repository.delay = true;
    final older = key.currentState!.refreshPages();
    final newer = key.currentState!.refreshPages();
    repository.requests[1].complete(repository.joined);
    await newer;
    await tester.pumpAndSettle();
    repository.requests[0].complete([]);
    await older;
    await tester.pumpAndSettle();
    expect(find.byType(CommunityProfilePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('empty following explores pages at large text dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: PagesHubPage(repository: HubRepository(), onChanged: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Create a page'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(find.text('You do not follow any pages yet'), findsOneWidget);
      final explore = find.widgetWithText(FilledButton, 'Explore pages');
      await tester.ensureVisible(explore);
      await tester.pumpAndSettle();
      await tester.tap(explore);
      await tester.pumpAndSettle();
      expect(find.text('Search pages'), findsOneWidget);
      expect(find.text('No pages found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'hub groups public identities and shows all followed pages (dark: $dark)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final business = page(
          'Managed business with a long display name',
          role: CommunityRole.admin,
          category: ProfileCategory.localBusiness,
        );
        final creator = page(
          'Managed creator',
          role: CommunityRole.owner,
          category: ProfileCategory.creator,
        );
        final repository = HubRepository()
          ..managed = [business, creator]
          ..joined = [
            business,
            creator,
            page('Ordinary community', type: CommunityType.community),
            for (var i = 0; i < 5; i++) page('Followed $i'),
          ];
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: PagesHubPage(repository: repository, onChanged: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 managed pages'), findsOneWidget);
        expect(find.text('Your pages and the ones you follow'), findsOneWidget);
        expect(
          find.text('Create, manage and follow public pages.'),
          findsNothing,
        );
        expect(find.text('Create a page'), findsNothing);
        expect(find.byTooltip('Create a page').hitTestable(), findsOneWidget);
        expect(find.text(business.name), findsOneWidget);
        expect(find.text(creator.name), findsOneWidget);
        expect(find.text('Ordinary community'), findsNothing);
        expect(
          find.text('Local business · Page administrator'),
          findsOneWidget,
        );
        expect(find.text('Creator · Page owner'), findsOneWidget);
        await tester.tap(find.text('Following'));
        await tester.pumpAndSettle();
        expect(find.text('5 followed pages'), findsOneWidget);
        await tester.drag(
          find.byKey(const PageStorageKey('followed-pages')),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(find.text('Followed 4'), findsOneWidget);
        expect(find.text(business.name), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty hub offers public page creation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PagesHubPage(repository: HubRepository(), onChanged: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('You do not manage any public pages yet.'),
      findsOneWidget,
    );
    expect(find.text('You do not follow any pages yet'), findsNothing);
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('You do not follow any pages yet'), findsOneWidget);
    await tester.tap(find.text('My pages'));
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create a page');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CreateCommunityPage>(find.byType(CreateCommunityPage))
          .initialType,
      CommunityType.publicProfile,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed loading can retry and keeps create available', (
    tester,
  ) async {
    final repository = HubRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: PagesHubPage(repository: repository, onChanged: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Create a page'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('My pages'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
