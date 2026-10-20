import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/admin/rule_management_page.dart';
import 'package:wicchu/widgets/community_rules_list.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

class _RulesRepository extends DemoCommunityRepository {
  _RulesRepository(this.role, {this.canManage = true});
  final CommunityRole role;
  final bool canManage;
  bool updated = false;
  Community get community => Community(
    id: 'rules-test',
    name: 'Echeandía',
    description: '',
    town: const Town(id: 'town', name: 'Echeandía', countryCode: 'EC'),
    visibility: CommunityVisibility.public,
    createdBy: 'owner',
    createdAt: DateTime(2026),
    myRole: role,
  );
  @override
  Future<Community> getCommunity(String id) async => community;
  @override
  Future<CommunityRules> listRules(String id) async => CommunityRules(
    rules: [
      CommunityRule(
        id: 'one',
        title: updated ? 'Regla actualizada' : 'Respeto entre vecinos',
        description:
            'Trata a los demás con respeto. No se permiten insultos, amenazas ni ataques personales.',
      ),
      const CommunityRule(
        id: 'two',
        title: 'Contenido relevante',
        description:
            'Comparte contenido relacionado con Echeandía. Evita el spam y las promociones no autorizadas.',
      ),
      const CommunityRule(
        id: 'three',
        title: 'Respeta la privacidad',
        description:
            'No compartas información personal de otras personas sin su consentimiento.',
      ),
      const CommunityRule(
        id: 'four',
        title: 'Actividades ilegales',
        description:
            'No se permiten actividades ilegales dentro de la comunidad.',
      ),
    ],
    rulesVersion: 1,
    acceptedRulesVersion: 1,
    acceptanceRequired: false,
    canManage: canManage,
  );
}

void main() {
  for (final role in CommunityRole.values) {
    testWidgets('rules edit permission for $role', (tester) async {
      final repository = _RulesRepository(role);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: repository.community,
            repository: repository,
            screen: CommunityScreen.rules,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Community rules'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.text('01'), findsOneWidget);
      final allowed =
          role == CommunityRole.owner || role == CommunityRole.admin;
      expect(
        find.widgetWithText(TextButton, 'Edit'),
        allowed ? findsOneWidget : findsNothing,
      );
      if (allowed) {
        await tester.tap(find.widgetWithText(TextButton, 'Edit'));
        await tester.pumpAndSettle();
        expect(find.byType(RuleManagementPage), findsOneWidget);
        repository.updated = true;
        Navigator.of(tester.element(find.byType(RuleManagementPage))).pop();
        await tester.pumpAndSettle();
        expect(find.text('Regla actualizada'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('API denial hides edit even for an administrator', (
    tester,
  ) async {
    final repository = _RulesRepository(CommunityRole.admin, canManage: false);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: repository.community,
          repository: repository,
          screen: CommunityScreen.rules,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Edit'), findsNothing);
  });
  testWidgets(
    'Spanish flat rules screenshots in both themes at enlarged text',
    (tester) async {
      final manifest =
          await rootBundle.loadString('FontManifest.json').then(jsonDecode)
              as List<dynamic>;
      for (final entry in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(entry['family'] as String);
        for (final font
            in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final dark in [false, true]) {
        final repository = _RulesRepository(CommunityRole.admin);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? WicchuTheme.dark : WicchuTheme.light,
              locale: const Locale('es'),
              supportedLocales: const [Locale('es')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: CommunityProfilePage(
                community: repository.community,
                repository: repository,
                screen: CommunityScreen.rules,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CommunityRulesList), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/wicchu-rules-${dark ? "dark" : "light"}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.ensureVisible(find.text('Actividades ilegales'));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
