import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  testWidgets('category list in Spanish, both themes and accessible sizes', (
    tester,
  ) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts']) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoCommunityRepository();
    final community = await repository.getCommunity('town-x-community');
    for (final narrow in [false, true]) {
      await tester.binding.setSurfaceSize(
        Size(narrow ? 320 : 430, narrow ? 740 : 1000),
      );
      for (final dark in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: AppLanguageScope(
              languageCode: 'es',
              onLanguageChanged: (_) {},
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? WicchuTheme.dark : WicchuTheme.light,
                locale: const Locale('es'),
                supportedLocales: const [Locale('es')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
                  child: child!,
                ),
                home: CategoryManagementPage(
                  community: community,
                  repository: repository,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(String section) async {
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('/tmp/wicchu-categories-review');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/${narrow ? "narrow" : "standard"}-${dark ? "dark" : "light"}-$section.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        expect(find.byType(CircleAvatar), findsNothing);
        expect(find.byType(Card), findsNothing);
        expect(
          find.byKey(const ValueKey('add-managed-category')).hitTestable(),
          findsOneWidget,
        );
        await capture('categories');
        final row = find.byType(ListTile).first;
        if (!narrow) expect(tester.getSize(row).height, lessThanOrEqualTo(64));
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
