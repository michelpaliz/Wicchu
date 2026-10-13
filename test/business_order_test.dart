import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/community/business_order_pages.dart';
import 'package:wicchu/theme/wicchu_icons.dart';

class _BusinessOrderRepository extends DemoCommunityRepository {
  BusinessOrderInput? submitted;
  bool failNext = false;

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
    if (failNext) {
      failNext = false;
      throw Exception("Temporary failure");
    }
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

class _DelayedOrderRepository extends _BusinessOrderRepository {
  final pending = Completer<void>();
  @override
  Future<BusinessOrder> createBusinessOrder(
    String businessId,
    BusinessOrderInput input,
  ) async {
    await pending.future;
    return super.createBusinessOrder(businessId, input);
  }
}

void main() {
  testWidgets(
    'checkout can close during submission without duplicate orders or crashes',
    (tester) async {
      final repository = _DelayedOrderRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessMenuPage(
            businessId: 'burger-house',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(WicchuIcons.plusCircle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'Review order · $4.50'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pickup').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Place order'));
      await tester.tap(find.text('Place order'));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      final reviewButton = find.ancestor(
        of: find.text(r'Review order · $4.50'),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(reviewButton).onPressed, isNull);
      repository.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Order sent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delivery validates address, preserves checkout after failure, then submits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _BusinessOrderRepository()..failNext = true;
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessMenuPage(
            businessId: 'burger-house',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(WicchuIcons.plusCircle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'Review order · $4.50'));
      await tester.pumpAndSettle();
      expect(find.text('1 × Classic burger'), findsOneWidget);
      await tester.ensureVisible(find.text('Place order'));
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(repository.submitted, isNull);
      expect(find.text('Enter a delivery address.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Delivery address'),
        'Main Street 12',
      );
      await tester.ensureVisible(find.text('Place order'));
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(find.text('Review your order'), findsOneWidget);
      expect(repository.submitted, isNull);
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(repository.submitted!.deliveryAddress, 'Main Street 12');
      expect(repository.submitted!.lines.single.quantity, 1);
      expect(find.text('Order sent'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text(r'Review order · $4.50'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
