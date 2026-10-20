import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/create_community_page.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class _GlobalWeatherRepository extends DemoCommunityRepository {
  _GlobalWeatherRepository(this.community);
  final Community community;
  int weatherRequests = 0;

  @override
  Future<Community> getCommunity(String id) async => community;

  @override
  Future<CommunityWeather?> getCommunityWeather(String communityId) async {
    weatherRequests++;
    return null;
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('reach choices fit small Spanish screen, dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: CreateCommunityPage(repository: DemoCommunityRepository()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Worldwide');
      await tester.pumpAndSettle();
      final next = find.widgetWithText(FilledButton, 'Continuar');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final anywhere = find.widgetWithText(ChoiceChip, 'Cualquier lugar');
      await tester.ensureVisible(anywhere);
      await tester.tap(anywhere);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(anywhere).selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('global information has no map action or weather request', (
    tester,
  ) async {
    final community = Community(
      id: 'worldwide',
      name: 'Worldwide',
      description: 'Everyone is welcome',
      scope: CommunityScope.global,
      town: const Town(id: '', name: 'Everywhere', countryCode: ''),
      visibility: CommunityVisibility.public,
      createdBy: 'current-user',
      createdAt: DateTime(2026),
      showWeather: true,
    );
    final repository = _GlobalWeatherRepository(community);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: repository,
          screen: CommunityScreen.information,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.weatherRequests, 0);
    expect(find.text('Everywhere, '), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Location'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Open to people everywhere'), findsWidgets);
    final locationRow = find.ancestor(
      of: find.text('Location'),
      matching: find.byType(InkWell),
    );
    expect(locationRow, findsWidgets);
    for (final row in tester.widgetList<InkWell>(locationRow)) {
      expect(row.onTap, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  test(
    'global community stays global after editing and is excluded nearby',
    () async {
      final repository = DemoCommunityRepository();
      final global = await repository.createCommunity(
        const CreateCommunityInput(
          name: 'Worldwide',
          description: 'Everyone',
          scope: CommunityScope.global,
          visibility: CommunityVisibility.public,
          categoryNames: ['General'],
        ),
      );
      expect(
        (await repository.listCommunities()).any((c) => c.id == global.id),
        isTrue,
      );
      expect(
        (await repository.listNearbyCommunities(
          latitude: 0,
          longitude: 0,
        )).any((c) => c.id == global.id),
        isFalse,
      );
      final updated = await repository.updateCommunity(
        global,
        town: global.town,
        name: 'Worldwide edited',
        description: global.description,
        visibility: global.visibility,
        approvalRequired: false,
        showWeather: false,
        links: [],
        businessServices: [],
        businessLocation: null,
      );
      expect(updated.isGlobal, isTrue);
    },
  );

  testWidgets('global creation skips location and previews its reach', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      MaterialApp(home: CreateCommunityPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Community name'),
      'Worldwide',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anywhere'));
    await tester.pumpAndSettle();
    expect(find.text('Use my current location'), findsNothing);
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Open to people everywhere'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Create space').last);
    await tester.pumpAndSettle();
    expect(find.text('Your community is ready!'), findsOneWidget);
    final created = (await repository.listCommunities()).singleWhere(
      (c) => c.name == 'Worldwide',
    );
    expect(created.isGlobal, isTrue);
    expect(created.town.id, isEmpty);
  });
}
