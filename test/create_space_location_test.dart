import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/create_community_page.dart';
import 'package:wicchu/services/place_search_service.dart';

class _LocationRepository extends DemoCommunityRepository {
  (double, double)? coordinates;
  @override
  Future<Town> locateTown({
    required double latitude,
    required double longitude,
  }) async {
    coordinates = (latitude, longitude);
    return const Town(id: 'remote-town', name: 'Echeandía', countryCode: 'EC');
  }
}

void main() {
  testWidgets('remote location works without GPS and survives GPS failure', (
    tester,
  ) async {
    final repository = _LocationRepository();
    var gpsRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateCommunityPage(
          repository: repository,
          locateCurrentTown: () async {
            gpsRequests++;
            throw Exception(
              'Location permission was denied. You can search for a location instead.',
            );
          },
          searchPlaces: (query, language) async {
            expect(query, 'Echeandia');
            return const [
              PlaceResult(
                name: 'Echeandía',
                region: 'Bolívar',
                country: 'Ecuador',
                latitude: -1.43,
                longitude: -79.28,
              ),
            ];
          },
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Community name'),
      'Remote community',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(gpsRequests, 0);
    await tester.tap(find.text('Search city or place'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('place-search')),
      'Echeandia',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Echeandía'));
    await tester.pumpAndSettle();
    expect(find.text('Echeandía, Bolívar, Ecuador'), findsOneWidget);
    expect(repository.coordinates, (-1.43, -79.28));
    expect(gpsRequests, 0);
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();
    expect(gpsRequests, 1);
    expect(find.text('Echeandía, Bolívar, Ecuador'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
