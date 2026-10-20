import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/business_order_pages.dart';
import 'package:wicchu/features/community/business_request_pages.dart';
import 'package:wicchu/theme/wicchu_icons.dart';

class _Repository extends DemoCommunityRepository {
  _Repository({
    this.enabled = false,
    this.accepting = false,
    this.owner = true,
    this.admin = false,
    this.orderPermission = false,
    this.withCategory = false,
    this.withProduct = false,
  });
  final bool enabled;
  final bool accepting;
  final bool owner;
  final bool admin;
  final bool orderPermission;
  final bool withCategory;
  final bool withProduct;
  List<BusinessFulfillmentOption> savedFulfillment = [];
  @override
  Future<BusinessRequestSettings> getBusinessRequestSettings(String id) async =>
      BusinessRequestSettings(
        businessId: id,
        businessName: 'Test',
        acceptingRequests: accepting,
        capabilities: enabled ? [BusinessRequestType.appointment] : [],
      );
  @override
  Future<List<BusinessRequest>> listManagedBusinessRequests(String id) async =>
      [];
  @override
  Future<BusinessCatalog> getBusinessCatalog(
    String id, {
    bool manage = false,
  }) async => BusinessCatalog(
    businessId: id,
    businessName: 'Test',
    acceptingOrders: accepting,
    fulfillmentOptions: savedFulfillment,
    categories: withCategory
        ? const [BusinessCatalogCategory(id: 'food', name: 'Food')]
        : const [],
    products: withProduct
        ? const [
            BusinessProduct(
              id: 'burger',
              categoryId: 'food',
              name: 'Burger',
              priceCents: 500,
            ),
          ]
        : const [],
  );

  @override
  Future<Community> getCommunity(String id) async => Community(
    id: id,
    name: 'Test',
    description: '',
    town: const Town(id: 'test-town', name: 'Test', countryCode: 'ES'),
    visibility: CommunityVisibility.public,
    createdBy: 'owner',
    createdAt: DateTime(2026),
    type: CommunityType.publicProfile,
    profileCategory: ProfileCategory.localBusiness,
    myRole: owner
        ? CommunityRole.owner
        : admin
        ? CommunityRole.admin
        : null,
    canManagePageOrders: orderPermission,
  );

  @override
  Future<void> setBusinessAcceptingOrders(
    String businessId, {
    required bool accepting,
    List<BusinessFulfillmentOption>? fulfillmentOptions,
  }) async {
    if (fulfillmentOptions != null) {
      savedFulfillment = List.unmodifiable(fulfillmentOptions);
    }
  }
}

void main() {
  for (final granted in [false, true]) {
    testWidgets('catalog management respects admin order permission=$granted', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessMenuPage(
            businessId: 'page',
            repository: _Repository(
              owner: false,
              admin: true,
              orderPermission: granted,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Manage catalog'),
        granted ? findsOneWidget : findsNothing,
      );
    });
  }

  for (final state in [(false, false), (true, false), (true, true)]) {
    testWidgets(
      'request empty state enabled=${state.$1} accepting=${state.$2}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BusinessRequestManagementPage(
              businessId: 'test',
              businessName: 'Test',
              repository: _Repository(enabled: state.$1, accepting: state.$2),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            !state.$1
                ? 'Enable your services to receive requests'
                : !state.$2
                ? 'Requests are paused'
                : 'You have not received any requests yet',
          ),
          findsOneWidget,
        );
        expect(find.byType(ChoiceChip), findsNothing);
        if (!state.$2) {
          await tester.tap(find.text('Configure requests'));
          await tester.pumpAndSettle();
          expect(find.byType(BusinessRequestSettingsPage), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('empty catalog has an add action without ordering controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessCatalogManagementPage(
          businessId: 'test',
          businessName: 'Test',
          repository: _Repository(withCategory: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Accept orders'), findsNothing);
    expect(find.text('Orders'), findsNothing);
    expect(find.text('Your catalog is empty'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.ensureVisible(find.text('Add product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Save product'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner can manage an empty catalog from the customer menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessMenuPage(businessId: 'test', repository: _Repository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The menu is being prepared'), findsOneWidget);
    expect(find.text('Manage catalog'), findsOneWidget);
    await tester.tap(find.text('Manage catalog'));
    await tester.pumpAndSettle();

    expect(find.byType(BusinessCatalogManagementPage), findsOneWidget);
    expect(find.text('Your catalog is empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor does not see catalog management in the empty menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessMenuPage(
          businessId: 'test',
          repository: _Repository(owner: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The menu is being prepared'), findsOneWidget);
    expect(find.text('Manage catalog'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order configuration is hidden from catalog management', (
    tester,
  ) async {
    final repository = _Repository(withCategory: true);
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessCatalogManagementPage(
          businessId: 'test',
          businessName: 'Test',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accept orders'), findsNothing);
    expect(find.text('Order methods'), findsNothing);
    expect(find.text('Orders'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor never sees the incomplete ordering configuration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessMenuPage(
          businessId: 'test',
          repository: _Repository(
            accepting: true,
            owner: false,
            withCategory: true,
            withProduct: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Ordering setup incomplete'), findsNothing);
    expect(
      find.text(
        'Delivery, pickup or eat-in must be configured before customers can order.',
      ),
      findsNothing,
    );
    expect(find.byIcon(WicchuIcons.plusCircle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner menu also hides ordering configuration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessMenuPage(
          businessId: 'test',
          repository: _Repository(
            accepting: true,
            withCategory: true,
            withProduct: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Ordering setup incomplete'), findsNothing);
    expect(find.byIcon(WicchuIcons.plusCircle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
