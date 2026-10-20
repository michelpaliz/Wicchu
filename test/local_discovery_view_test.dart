import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
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
    Community(
      id: 'wicchu',
      name: 'Wicchu',
      description: 'Community services',
      town: town,
      visibility: CommunityVisibility.public,
      createdBy: 'owner-3',
      createdAt: DateTime.utc(2026),
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.organization,
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
  Future<List<Community>> listCommunities({
    String? query,
    String? townId,
  }) async => businesses;

  @override
  Future<List<Community>> listLocalBusinesses({
    String? townId,
    String? query,
  }) async {
    requestedAnywhere = townId == null;
    return businesses.reversed.toList(growable: false);
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
  for (final dark in [false, true]) {
    testWidgets('denied nearby location offers manual town in theme $dark', (
      tester,
    ) async {
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'isLocationServiceEnabled') return true;
        return 0;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          home: Scaffold(
            body: LocalDiscoveryView(repository: _LocalDiscoveryRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('discovery-location-filters')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Near me').last);
      await tester.pumpAndSettle();
      final manual = find.widgetWithText(TextButton, 'Choose town').last;
      await tester.ensureVisible(manual);
      await tester.tap(manual);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Echeandía').last);
      await tester.pumpAndSettle();
      expect(find.text('Show results').hitTestable(), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('business_discovery_location_mode'), 'town');
      expect(tester.takeException(), isNull);
    });
  }

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
    'local discovery lists businesses alphabetically and filters categories',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalDiscoveryView(repository: _LocalDiscoveryRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('discovery-filters')), findsNothing);
      expect(find.text('Como en Casa'), findsWidgets);
      expect(find.widgetWithText(FilterChip, 'Delivery'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Como en Casa').first).dy,
        lessThan(tester.getTopLeft(find.text('Transporte Express').first).dy),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
      await tester.pumpAndSettle();
      expect(find.text('Como en Casa'), findsOneWidget);
      expect(find.text('Echeandía → Guayaquil'), findsNothing);
      expect(find.byKey(const ValueKey('discovery-filters')), findsNothing);
    },
  );

  testWidgets('food discovery directly shows available restaurants', (
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

    expect(find.text('Como en Casa'), findsOneWidget);
    expect(find.text('Transporte Express'), findsNothing);
    expect(find.text('1 restaurant available'), findsOneWidget);
    expect(find.text("Today's menus"), findsNothing);
  });

  testWidgets('organization pages appear in all and services discovery', (
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

    expect(find.text('Wicchu'), findsOneWidget);
    expect(find.textContaining('Organization'), findsOneWidget);
    expect(find.text('3 results found'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Services'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Services'));
    await tester.pumpAndSettle();

    expect(find.text('Wicchu'), findsOneWidget);
    expect(find.text('1 result found'), findsOneWidget);
    expect(find.text('Como en Casa'), findsNothing);
    expect(find.text('Transporte Express'), findsNothing);
  });

  testWidgets('business discovery remembers an anywhere location mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'business_discovery_location_mode': 'town',
    });
    final repository = _LocalDiscoveryRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalDiscoveryView(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('discovery-location-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('My town · Echeandía'), findsOneWidget);
    expect(find.text('Show results').hitTestable(), findsOneWidget);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(
        tester.view.physicalSize.height / tester.view.devicePixelRatio * .6,
      ),
    );
    await tester.ensureVisible(find.text('Anywhere').last);
    await tester.tap(find.text('Anywhere').last);
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
