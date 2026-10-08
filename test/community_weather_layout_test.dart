import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class _WeatherRepository extends DemoCommunityRepository {
  @override
  Future<CommunityWeather?> getCommunityWeather(String communityId) async =>
      const CommunityWeather(
        townName: 'Echeandía',
        temperature: 31,
        apparentTemperature: 32,
        minTemperature: 23,
        maxTemperature: 32,
        weatherCode: 1,
        description: 'Mainly clear',
        isDay: true,
        observedAt: null,
        provider: 'Open-Meteo',
      );
}

void main() {
  for (final scenario in [(390.0, 1.0), (320.0, 1.0), (390.0, 1.6)]) {
    testWidgets(
      'weather description fits at ${scenario.$1}dp and ${scenario.$2} text scale',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(scenario.$1, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final community = Community(
          id: 'town-x-community',
          name: 'Echeandia',
          description: 'Comunidad local',
          town: const Town(id: 'town-1', name: 'Echeandía', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          createdBy: 'current-user',
          createdAt: DateTime(2026),
          myRole: CommunityRole.member,
          showWeather: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
              child: child!,
            ),
            home: CommunityProfilePage(
              community: community,
              repository: _WeatherRepository(),
              screen: CommunityScreen.information,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Mayormente despejado'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Mayormente despejado')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        expect(find.text('Mayormente despejado'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Mayormente despejado'));
        await tester.pumpAndSettle();
        expect(find.text('31°C · Mayormente despejado'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
