import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/local_discovery_view.dart';

class _LocalDiscoveryRepository extends DemoCommunityRepository {
  static const town = Town(
    id: 'echeandia',
    name: 'Echeandía',
    countryCode: 'EC',
  );

  final businesses = [
    Community(
      id: 'restaurant',
      name: 'Como en Casa',
      description: '',
      town: town,
      visibility: CommunityVisibility.public,
      createdBy: 'owner-1',
      createdAt: DateTime.utc(2026),
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.localBusiness,
      businessServices: const [BusinessService.food],
    ),
    Community(
      id: 'transport',
      name: 'Transporte Express',
      description: '',
      town: town,
      visibility: CommunityVisibility.public,
      createdBy: 'owner-2',
      createdAt: DateTime.utc(2026),
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.localBusiness,
      businessServices: const [BusinessService.transport],
    ),
  ];

  late final posts = [
    CommunityPost(
      id: 'menu',
      communityId: 'restaurant',
      categoryId: 'posts',
      authorId: 'owner-1',
      authorName: 'Como en Casa',
      text: "Today's menu",
      status: PostStatus.published,
      createdAt: DateTime.now(),
      todayMenu: TodayMenu(
        dishes: const [TodayMenuDish(name: 'Seco de carne', price: r'$3.50')],
        fulfillmentOptions: const [BusinessFulfillmentOption.delivery],
        expiresAt: DateTime.now().add(const Duration(hours: 8)),
      ),
    ),
    CommunityPost(
      id: 'trip',
      communityId: 'transport',
      categoryId: 'posts',
      authorId: 'owner-2',
      authorName: 'Transporte Express',
      text: 'Echeandía to Guayaquil',
      status: PostStatus.published,
      createdAt: DateTime.now(),
      businessFeature: BusinessPostFeature(
        type: BusinessPostFeatureType.transportTrip,
        routeFrom: 'Echeandía',
        routeTo: 'Guayaquil',
        seatsAvailable: 4,
        price: r'$12',
        departureAt: DateTime.now().add(const Duration(days: 1)),
      ),
    ),
  ];

  bool requestedAnywhere = false;

  @override
  Future<List<Town>> listTowns() async => const [town];

  @override
  Future<List<Community>> listJoinedCommunities() async => businesses;

  @override
  Future<List<Community>> listCommunities({String? query}) async => businesses;

  @override
  Future<List<Community>> listLocalBusinesses({
    String? townId,
    String? query,
  }) async {
    requestedAnywhere = townId == null;
    return businesses;
  }

  @override
  Future<List<CommunityPost>> listBusinessPosts(
    List<String> businessIds, {
    String? query,
  }) async => posts;

  @override
  Future<List<CommunityPost>> listLocalBusinessPosts(
    String townId, {
    String? query,
  }) async => posts;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('multiple categories are combined and retained after reopening', (
    tester,
  ) async {
    Widget screen() => MaterialApp(
      home: Scaffold(
        body: LocalDiscoveryView(repository: _LocalDiscoveryRepository()),
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Transport'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transport'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('business_filter_categories'),
      containsAll(['food', 'transport']),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Food'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Transport'))
          .selected,
      isTrue,
    );
    expect(find.text('Como en Casa'), findsWidgets);
    expect(find.text('Transporte Express'), findsWidgets);
  });

  testWidgets(
    'local discovery groups structured posts and filters categories',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalDiscoveryView(repository: _LocalDiscoveryRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('discovery-filters')), findsOneWidget);
      expect(find.text('Como en Casa'), findsWidgets);
      expect(find.widgetWithText(FilterChip, 'Delivery'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
      await tester.pumpAndSettle();
      expect(find.text('Seco de carne'), findsOneWidget);
      expect(find.text('Echeandía → Guayaquil'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('discovery-filters')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'Delivery'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Delivery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets('food discovery switches from menus to restaurants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocalDiscoveryView(repository: _LocalDiscoveryRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();

    expect(find.text('Como en Casa'), findsOneWidget);
    expect(find.text('Transporte Express'), findsNothing);
  });

  testWidgets('business discovery remembers an anywhere location mode', (
    tester,
  ) async {
    final repository = _LocalDiscoveryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalDiscoveryView(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('discovery-location-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Anywhere'));
    await tester.pumpAndSettle();

    expect(repository.requestedAnywhere, isTrue);
    expect(find.textContaining('Anywhere'), findsWidgets);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('business_discovery_location_mode'),
      'anywhere',
    );
  });
}
