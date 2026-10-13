import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/community/business_order_pages.dart';
import 'package:wicchu/theme/wicchu_icons.dart';

class _BusinessOrderRepository extends DemoCommunityRepository {
  BusinessOrderInput? submitted;

  @override
  Future<BusinessCatalog> getBusinessCatalog(
    String businessId, {
    bool manage = false,
  }) async => const BusinessCatalog(
    businessId: 'burger-house',
    businessName: 'Burger House',
    acceptingOrders: true,
    fulfillmentOptions: [
      BusinessFulfillmentOption.delivery,
      BusinessFulfillmentOption.pickup,
    ],
    categories: [BusinessCatalogCategory(id: 'burgers', name: 'Burgers')],
    products: [
      BusinessProduct(
        id: 'classic',
        categoryId: 'burgers',
        name: 'Classic burger',
        priceCents: 450,
      ),
    ],
  );

  @override
  Future<BusinessOrder> createBusinessOrder(
    String businessId,
    BusinessOrderInput input,
  ) async {
    submitted = input;
    return BusinessOrder(
      id: 'order-1',
      businessId: businessId,
      orderNumber: 1042,
      status: BusinessOrderStatus.pending,
      fulfillmentMethod: input.fulfillmentMethod,
      subtotalCents: 450,
      items: const [
        BusinessOrderItem(
          productId: 'classic',
          name: 'Classic burger',
          quantity: 1,
          unitPriceCents: 450,
          totalCents: 450,
        ),
      ],
      createdAt: DateTime(2026, 10, 13),
    );
  }
}

class _VariantOrderRepository extends _BusinessOrderRepository {
  @override
  Future<BusinessCatalog> getBusinessCatalog(
    String businessId, {
    bool manage = false,
  }) async => const BusinessCatalog(
    businessId: 'shop-1',
    businessName: 'Local Shop',
    acceptingOrders: true,
    fulfillmentOptions: [BusinessFulfillmentOption.pickup],
    categories: [BusinessCatalogCategory(id: 'clothes', name: 'Clothes')],
    products: [
      BusinessProduct(
        id: 'shirt',
        categoryId: 'clothes',
        name: 'Wicchu shirt',
        priceCents: 1200,
        variants: [
          BusinessProductVariant(
            id: 'shirt-m-blue',
            name: 'Medium · Blue',
            sku: 'SH-M-BLU',
            priceCents: 1300,
            quantityAvailable: 2,
            attributes: {'Size': 'M', 'Color': 'Blue'},
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('customer can add a menu item and review the order', (
    tester,
  ) async {
    final repository = _BusinessOrderRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessMenuPage(
          businessId: 'burger-house',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Burger House'), findsOneWidget);
    expect(find.text('Classic burger'), findsOneWidget);
    await tester.tap(find.byIcon(WicchuIcons.plusCircle));
    await tester.pumpAndSettle();
    expect(find.text(r'Review order · $4.50'), findsOneWidget);
    await tester.tap(find.text(r'Review order · $4.50'));
    await tester.pumpAndSettle();
    expect(find.text('Review your order'), findsOneWidget);
    expect(find.text(r'Subtotal: $4.50'), findsOneWidget);
  });

  testWidgets('customer selects a stocked physical product variant', (
    tester,
  ) async {
    final repository = _VariantOrderRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessMenuPage(businessId: 'shop-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Medium · Blue'), findsOneWidget);
    expect(find.textContaining('SH-M-BLU'), findsOneWidget);
    await tester.tap(find.byIcon(WicchuIcons.plusCircle));
    await tester.pumpAndSettle();
    expect(find.text(r'Review order · $13.00'), findsOneWidget);
  });
}
