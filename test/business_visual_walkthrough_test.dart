import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/business_order_pages.dart';
import 'package:wicchu/features/community/business_request_pages.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/theme/wicchu_icons.dart';

class _VisualRepository extends DemoCommunityRepository {
  @override
  Future<BusinessCatalog> getBusinessCatalog(
    String businessId, {
    bool manage = false,
  }) async => const BusinessCatalog(
    businessId: 'visual-business',
    businessName: 'Negocio de prueba',
    acceptingOrders: true,
    fulfillmentOptions: [
      BusinessFulfillmentOption.delivery,
      BusinessFulfillmentOption.pickup,
    ],
    categories: [BusinessCatalogCategory(id: 'food', name: 'Hamburguesas')],
    products: [
      BusinessProduct(
        id: 'burger',
        categoryId: 'food',
        name: 'Hamburguesa clásica',
        description: 'Pan, carne, queso y vegetales.',
        priceCents: 450,
      ),
    ],
  );
}

void main() {
  testWidgets('capture business flow screens with test data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts']) {
        if (entry['family'] == 'Plus Jakarta Sans' &&
            !(font['asset'] as String).endsWith('-400.ttf')) {
          continue;
        }
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    final repository = _VisualRepository();
    final boundary = GlobalKey();
    Future<void> open(Widget page, {bool light = false}) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: light ? WicchuTheme.light : WicchuTheme.dark,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await Directory('/tmp/wicchu-business-review').create(recursive: true);
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/wicchu-business-review/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> tap(String text) async {
      final finder = find.text(text).last;
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await open(
      BusinessMenuPage(businessId: 'visual-business', repository: repository),
    );
    await shot('test-01-catalog');
    await tester.tap(find.byIcon(WicchuIcons.plusCircle));
    await tester.pumpAndSettle();
    await shot('test-02-cart');
    await tap(r'Revisar pedido · $4.50');
    await shot('test-03-checkout');
    await tap('Enviar pedido');
    await shot('test-04-address-validation');
    await tester.enterText(
      find.widgetWithText(TextField, 'Dirección de entrega'),
      'Calle de prueba 12',
    );
    await shot('test-05-address-filled');
    await tap('Enviar pedido');
    await shot('test-06-order-confirmation');
    await tap('Listo');
    await open(MyBusinessOrdersPage(repository: repository));
    expect(find.text('Aceptar pedido'), findsNothing);
    expect(find.text('Cancelar pedido'), findsOneWidget);
    await shot('test-07-my-orders');
    await open(
      BusinessTransactionsPage(
        businessId: 'visual-business',
        businessName: 'Negocio de prueba',
        repository: repository,
      ),
    );
    await shot('test-08-dashboard');
    await open(
      BusinessOrderManagementPage(
        businessId: 'visual-business',
        businessName: 'Negocio de prueba',
        repository: repository,
      ),
    );
    await shot('test-09-manage-orders');
    await tap('Aceptar pedido');
    await shot('test-09b-order-accepted');
    await tap('Empezar a preparar');
    await shot('test-09c-order-preparing');
    await tap('Marcar como listo');
    await shot('test-09d-order-ready');
    await tap('Marcar como completado');
    await shot('test-09e-order-completed');
    await open(
      BusinessCatalogManagementPage(
        businessId: 'visual-business',
        businessName: 'Negocio de prueba',
        repository: repository,
      ),
    );
    await shot('test-10-manage-catalog');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await shot('test-11-product-editor');
    await tap('Añadir talla o color');
    await shot('test-11b-variant-editor');
    await open(
      BusinessRequestComposerPage(
        businessId: 'visual-business',
        repository: repository,
      ),
    );
    await shot('test-12-service-request');
    await tester.enterText(
      find.widgetWithText(TextField, '¿Qué servicio necesitas?'),
      'Mantenimiento del jardín',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Describe lo que necesitas'),
      'Revisar el riego y recortar los arbustos.',
    );
    await shot('test-13-request-filled');
    await tap('Enviar solicitud');
    await shot('test-14-request-confirmation');
    await open(MyBusinessRequestsPage(repository: repository));
    await shot('test-15-my-requests');
    await open(
      BusinessRequestManagementPage(
        businessId: 'visual-business',
        businessName: 'Negocio de prueba',
        repository: repository,
      ),
    );
    await shot('test-16-manage-requests');
    await tap('Enviar presupuesto');
    await shot('test-16b-quote-editor');
    await tester.enterText(find.byType(TextField).last, '25');
    await tap('Continuar');
    await shot('test-16c-quoted-request');
    await open(
      BusinessRequestSettingsPage(
        businessId: 'visual-business',
        repository: repository,
      ),
    );
    await shot('test-17-request-settings');
    await open(
      BusinessMenuPage(businessId: 'visual-business', repository: repository),
      light: true,
    );
    await shot('test-18-light-catalog');
  });
}
