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

      expect(find.text('Discover local businesses'), findsOneWidget);
      expect(find.text("Today's menus"), findsOneWidget);
      expect(find.text('Upcoming transport'), findsOneWidget);
      expect(find.text('Seco de carne'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
      await tester.pumpAndSettle();
      expect(find.text('Seco de carne'), findsOneWidget);
      expect(find.text('Echeandía → Guayaquil'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'Delivery'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(ChoiceChip, 'Anywhere'));
    await tester.pumpAndSettle();

    expect(repository.requestedAnywhere, isTrue);
    expect(
      find.text('Explore local businesses from every available town'),
      findsOneWidget,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('business_discovery_location_mode'),
      'anywhere',
    );
  });
}
