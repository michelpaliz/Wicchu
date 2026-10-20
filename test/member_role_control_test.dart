import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

class _Repository extends DemoCommunityRepository {
  _Repository(
    ProfileCategory? category,
    CommunityRole viewerRole, {
    this.fail = false,
  }) : community = Community(
         id: 'role-test',
         name: 'Test space',
         description: '',
         town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
         visibility: CommunityVisibility.public,
         createdBy: 'owner',
         createdAt: DateTime(2026),
         myRole: viewerRole,
         type: category != null
             ? CommunityType.publicProfile
             : CommunityType.community,
         profileCategory: category,
       );
  final Community community;
  final bool fail;
  CommunityRole role = CommunityRole.member;
  int writes = 0;
  int invitations = 0;
  @override
  Future<void> createAdminInvitation(String id, String userId) async {
    invitations++;
    if (fail) throw Exception('Unable to invite administrator');
  }

  @override
  Future<Community> getCommunity(String id) async => community;
  @override
  Future<List<CommunityMember>> listMembers(
    String id, {
    bool includeInactive = false,
  }) async => [
    CommunityMember(
      userId: 'owner',
      communityId: id,
      name: 'Owner name',
      role: CommunityRole.owner,
      status: MembershipStatus.active,
      joinedAt: DateTime(2026),
    ),
    CommunityMember(
      userId: 'target',
      communityId: id,
      name: 'Target name',
      role: role,
      status: MembershipStatus.active,
      joinedAt: DateTime(2026),
    ),
  ];
  @override
  Future<void> setMemberRole(
    String id,
    String userId,
    CommunityRole value,
  ) async {
    writes++;
    if (fail) throw Exception('Unable to update role');
    role = value;
  }
}

void main() {
  testWidgets(
    'moderators belong to administration and member rows stay compact',
    (tester) async {
      final repository = _Repository(null, CommunityRole.member)
        ..role = CommunityRole.moderator;
      await tester.pumpWidget(
        MaterialApp(
          theme: WicchuTheme.light,
          home: CommunityProfilePage(
            community: repository.community,
            repository: repository,
            screen: CommunityScreen.members,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administration (2)'), findsOneWidget);
      expect(find.text('Members (0)'), findsOneWidget);
      expect(find.byKey(const ValueKey('member-role-target')), findsNothing);
      final row = find.ancestor(
        of: find.text('Target name'),
        matching: find.byType(ListTile),
      );
      expect(tester.getSize(row).height, inInclusiveRange(64, 72));
      await tester.tap(find.text('Administration (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Target name'), findsOneWidget);
      await tester.tap(find.text('Members (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Target name'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact Spanish selector shows current role and confirms demotion',
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
        final repository = _Repository(null, CommunityRole.owner)
          ..role = CommunityRole.admin;
        final boundary = GlobalKey();
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
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: CommunityProfilePage(
                community: repository.community,
                repository: repository,
                screen: CommunityScreen.members,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/wicchu-community-members-${dark ? "dark" : "light"}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.byKey(const ValueKey('member-role-target')));
        await tester.pumpAndSettle();
        expect(find.text('Rol actual: Administrador'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Guardar cambios'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<RadioGroup<CommunityRole>>(
                find.byType(RadioGroup<CommunityRole>),
              )
              .groupValue,
          CommunityRole.admin,
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/wicchu-community-role-${dark ? "dark" : "light"}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(
          find.widgetWithText(RadioListTile<CommunityRole>, 'Moderador'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Se retirarán los permisos'),
          findsOneWidget,
        );
        expect(repository.writes, 0);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(repository.role, CommunityRole.admin);
        expect(repository.writes, 0);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final category in <ProfileCategory?>[null, ...ProfileCategory.values]) {
    for (final fail in [false, true]) {
      testWidgets('role change category=$category failure=$fail', (
        tester,
      ) async {
        final repository = _Repository(
          category,
          CommunityRole.owner,
          fail: fail,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              community: repository.community,
              repository: repository,
              screen: CommunityScreen.members,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('member-role-owner')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('member-role-target')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            category == null ? 'Administrator' : 'Invite as page administrator',
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.writes, 0);
        if (category == null) {
          await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Send invitation'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.writes, 0);
        expect(repository.invitations, 1);
        expect(repository.role, CommunityRole.member);
        expect(
          find.text(
            category == null
                ? 'Community administrator invitation sent. The member must accept it.'
                : 'Page administrator invitation sent. The follower must accept it.',
          ),
          fail ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
      'admin can set moderator but cannot invite administrators category=$category',
      (tester) async {
        final repository = _Repository(category, CommunityRole.admin);
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              community: repository.community,
              repository: repository,
              screen: CommunityScreen.members,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('member-role-target')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            category == null ? 'Administrator' : 'Invite as page administrator',
          ),
          findsNothing,
        );
        final moderatorLabel = category == null
            ? 'Moderator'
            : 'Page moderator';
        await tester.tap(find.text(moderatorLabel));
        await tester.pumpAndSettle();
        if (category == null) {
          await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(repository.writes, 0);
        await tester.tap(find.byKey(const ValueKey('member-role-target')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(moderatorLabel));
        await tester.pumpAndSettle();
        if (category == null) {
          await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
        await tester.pumpAndSettle();
        expect(repository.writes, 1);
        expect(repository.invitations, 0);
        expect(repository.role, CommunityRole.moderator);
        expect(find.textContaining(moderatorLabel), findsOneWidget);
      },
    );
    testWidgets('ordinary viewer cannot change roles category=$category', (
      tester,
    ) async {
      final repository = _Repository(category, CommunityRole.member);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: repository.community,
            repository: repository,
            screen: CommunityScreen.members,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member-role-target')), findsNothing);
      expect(repository.writes, 0);
    });
  }
}
