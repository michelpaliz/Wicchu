import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/business_request_pages.dart';

class _DashboardRepository extends DemoCommunityRepository {
  _DashboardRepository(this.type, {this.products = false});
  final BusinessRequestType type;
  final bool products;
  @override
  Future<List<BusinessOrder>> listManagedBusinessOrders(String id) async => [];
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
    acceptingOrders: products,
    categories: products
        ? const [BusinessCatalogCategory(id: 'items', name: 'Items')]
        : const [],
    products: products
        ? const [
            BusinessProduct(
              id: 'item',
              categoryId: 'items',
              name: 'Item',
              priceCents: 100,
            ),
          ]
        : const [],
  );
  @override
  Future<BusinessRequestSettings> getBusinessRequestSettings(String id) async =>
      BusinessRequestSettings(
        businessId: id,
        businessName: 'Test',
        capabilities: [type],
      );
}

class _RestrictedDashboardRepository extends _DashboardRepository {
  _RestrictedDashboardRepository({required this.orders, required this.services})
    : super(BusinessRequestType.appointment, products: true);
  final bool orders;
  final bool services;
  int catalogReads = 0;
  int requestReads = 0;
  @override
  Future<Community> getCommunity(String id) async => Community(
    id: id,
    name: 'Restricted page',
    description: '',
    town: const Town(id: 'town', name: 'Town', countryCode: 'ES'),
    visibility: CommunityVisibility.public,
    createdBy: 'owner',
    createdAt: DateTime(2026),
    type: CommunityType.publicProfile,
    profileCategory: ProfileCategory.localBusiness,
    myRole: CommunityRole.admin,
    canManagePageOrders: orders,
    canManagePageServices: services,
  );
  @override
  Future<BusinessCatalog> getBusinessCatalog(
    String id, {
    bool manage = false,
  }) async {
    catalogReads++;
    if (!orders) throw StateError('Unauthorized catalog request');
    return super.getBusinessCatalog(id, manage: manage);
  }

  @override
  Future<List<BusinessRequest>> listManagedBusinessRequests(String id) async {
    requestReads++;
    if (!services) throw StateError('Unauthorized services request');
    return [];
  }

  @override
  Future<BusinessRequestSettings> getBusinessRequestSettings(String id) async {
    if (!services) throw StateError('Unauthorized settings request');
    return super.getBusinessRequestSettings(id);
  }
}

void main() {
  for (final permissions in [(true, false), (false, true), (false, false)]) {
    testWidgets('dashboard loads only granted modules $permissions', (
      tester,
    ) async {
      final repository = _RestrictedDashboardRepository(
        orders: permissions.$1,
        services: permissions.$2,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BusinessTransactionsPage(
            businessId: 'restricted',
            businessName: 'Restricted page',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.catalogReads, permissions.$1 ? 1 : 0);
      expect(repository.requestReads, permissions.$2 ? 1 : 0);
      expect(
        find.text('Catalog'),
        permissions.$1 ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Appointments and bookings'),
        permissions.$2 ? findsOneWidget : findsNothing,
      );
      expect(find.text('Set up catalog'), findsNothing);
      expect(find.text('Set up service requests'), findsNothing);
      if (!permissions.$1 && !permissions.$2) {
        expect(
          find.text('You do not have permission to manage this business.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in {
    BusinessRequestType.quote: 'Quotes and services',
    BusinessRequestType.appointment: 'Appointments and bookings',
    BusinessRequestType.taxi: 'Ride requests',
    BusinessRequestType.service: 'Service requests',
  }.entries) {
    testWidgets(
      'dashboard adapts to ${entry.key.name} without product module',
      (tester) async {
        final repository = _DashboardRepository(entry.key);
        final business = (await repository.listJoinedCommunities()).first;
        await tester.pumpWidget(
          MaterialApp(
            home: BusinessTransactionsPage(
              businessId: business.id,
              businessName: business.name,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Products and sales'), findsNothing);
        expect(find.text('Menu and orders'), findsNothing);
        expect(find.text('No requests yet'), findsOneWidget);
        expect(find.text('Service requests and bookings'), findsOneWidget);
        expect(find.byType(Card), findsNothing);
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();
        expect(find.byType(BusinessRequestManagementPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'enabled product and service modules coexist at large text scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _DashboardRepository(
        BusinessRequestType.quote,
        products: true,
      );
      final business = (await repository.listJoinedCommunities()).first;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: BusinessTransactionsPage(
            businessId: business.id,
            businessName: business.name,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Quotes and services'), findsOneWidget);
      expect(find.text('Set up product sales'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
