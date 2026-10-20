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
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/features/admin/financial_support_page.dart';
import 'package:wicchu/features/admin/platform_moderation_page.dart';
import 'package:wicchu/features/community/community_invitations_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

class _Repository extends DemoCommunityRepository {
  String? status;
  final page = Community(
    id: 'page',
    name: 'Asociación de vecinos de Echeandía',
    description: '',
    town: const Town(id: 'town', name: 'Echeandía', countryCode: 'EC'),
    visibility: CommunityVisibility.public,
    createdBy: 'owner',
    createdAt: DateTime(2026),
    myRole: CommunityRole.owner,
    type: CommunityType.publicProfile,
    profileCategory: ProfileCategory.organization,
  );
  FinancialSupportApplication application(
    String status,
  ) => FinancialSupportApplication(
    id: 'application',
    pageId: page.id,
    pageName: page.name,
    countryCode: 'EC',
    recipientType: 'community_project',
    purpose: 'Organizar talleres gratuitos para las familias de la comunidad.',
    contactEmail: 'asociacion@ejemplo.com',
    status: status,
    requestedAt: DateTime(2026),
    reviewNote: status == 'rejected'
        ? 'Indica quiénes participarán en los talleres y cómo se utilizará el apoyo.'
        : '',
  );
  @override
  Future<FinancialSupportApplication?> getFinancialSupportApplication(
    String id,
  ) async => status == null ? null : application(status!);
  @override
  Future<List<FinancialSupportApplication>>
  listFinancialSupportApplications() async => [application('pending')];
  @override
  Future<List<CommunityMember>> listMembers(
    String id, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'admin',
      communityId: id,
      name: 'María Fernanda Rodríguez',
      role: CommunityRole.admin,
      status: MembershipStatus.active,
      joinedAt: DateTime(2026),
    ),
  ];
  @override
  Future<List<CommunityInvitation>> listMyCommunityInvitations() async => [
    for (final type in ['admin_invitation', 'ownership_transfer'])
      CommunityInvitation(
        id: type,
        communityId: page.id,
        communityName: page.name,
        communityType: CommunityType.publicProfile,
        type: type,
        status: 'pending',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
  ];
}

void main() {
  testWidgets(
    'Spanish admin feature screenshots at standard and accessible sizes',
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
      final boundary = GlobalKey();
      final repository = _Repository();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final narrow in [false, true]) {
        await tester.binding.setSurfaceSize(
          Size(narrow ? 320 : 430, narrow ? 740 : 900),
        );
        for (final dark in [false, true]) {
          final prefix =
              '${narrow ? "narrow" : "standard"}-${dark ? "dark" : "light"}';
          Future<void> open(Widget page) async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? WicchuTheme.dark : WicchuTheme.light,
                  locale: const Locale('es'),
                  supportedLocales: const [Locale('es')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(narrow ? 1.3 : 1)),
                    child: child!,
                  ),
                  home: page,
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          Future<void> shot(String name) async {
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$prefix-$name');
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('/tmp/wicchu-admin-visual-review');
              await dir.create(recursive: true);
              await File(
                '${dir.path}/$prefix-$name.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          await open(MyCommunityInvitationsPage(repository: repository));
          await shot('invitations');
          await open(
            MemberManagementPage(
              community: repository.page,
              repository: repository,
            ),
          );
          await shot('members');
          await tester.tap(find.byKey(const ValueKey('member-actions-admin')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Permisos de la página'));
          await tester.tap(find.text('Permisos de la página'));
          await shot('permissions');
          await tester.ensureVisible(find.text('Gestor de ventas'));
          await tester.tap(find.text('Gestor de ventas'));
          await shot('permission-presets');
          await tester.ensureVisible(
            find.widgetWithText(CheckboxListTile, 'Analítica de la página'),
          );
          await shot('permission-options');
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.widgetWithText(CheckboxListTile, 'Mensajes'),
                )
                .value,
            isTrue,
          );
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.widgetWithText(CheckboxListTile, 'Pedidos'),
                )
                .value,
            isTrue,
          );

          await tester.tap(find.text('Cancelar'));
          for (final status in <String?>[
            null,
            'pending',
            'approved',
            'rejected',
          ]) {
            repository.status = status;
            await open(
              FinancialSupportPage(
                page: repository.page,
                repository: repository,
              ),
            );
            await shot('support-${status ?? "form"}');
          }
          await open(
            PlatformModerationPage(repository: repository, initialTab: 5),
          );
          await shot('queue');
        }
      }
    },
  );
}
