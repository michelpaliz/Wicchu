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
import 'package:wicchu/features/admin/local_news_settings_page.dart';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

class _VisualNewsRepository extends DemoCommunityRepository {
  @override
  Future<LocalNewsSettings> getLocalNewsSettings(String communityId) async =>
      LocalNewsSettings(
        enabled: true,
        activationRequested: true,
        sourceIds: const ['source-1'],
        categoryIds: const ['general'],
        language: 'es',
        approvalMode: 'manual',
        newsRules: const [
          LocalNewsRule(
            categoryId: 'general',
            include: 'Noticias locales, eventos y servicios de la comunidad.',
          ),
        ],
        access: const LocalNewsAccess(
          entitled: true,
          source: 'pilot',
          tier: 'pilot',
          monthlyLimit: 60,
          dailyLimit: 1,
        ),
        dashboard: LocalNewsDashboard(
          status: 'awaiting_approval',
          enabled: true,
          serviceState: 'active',
          view: 'dashboard',
          nextCollectionAt: DateTime.utc(2026, 10, 22, 12),
          quotaResetsAt: DateTime.utc(2026, 10, 23),
          pendingApproval: 1,
          publishedToday: 0,
          dailyLimit: 1,
          upcomingArticle: const LocalNewsUpcomingArticle(
            articleId: 'news-1',
            title: 'Nueva actividad para las familias de Echeandía',
            sourceName: 'Municipio de Echeandía',
          ),
        ),
      );
}

void main() {
  testWidgets('news screens in Spanish, both themes and accessible sizes', (
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
    final repository = _VisualNewsRepository();
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
                home: LocalNewsSettingsPage(
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
            final dir = Directory('/tmp/wicchu-news-review');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/${narrow ? "narrow" : "standard"}-${dark ? "dark" : "light"}-$section.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        final summaryTab = find.widgetWithText(Tab, 'Resumen');
        final pendingTab = find.widgetWithText(Tab, 'Pendiente');
        final settingsTab = find.widgetWithText(Tab, 'Ajustes');
        expect(summaryTab, findsOneWidget);
        expect(pendingTab, findsOneWidget);
        expect(settingsTab, findsOneWidget);
        await capture('summary');

        await tester.tap(pendingTab);
        await tester.pumpAndSettle();
        expect(find.text('Revisar noticias pendientes'), findsOneWidget);
        await capture('pending');

        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
        expect(find.text('Categoría de publicación *'), findsOneWidget);
        await capture('settings');
      }
    }
  });
}
