import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';
import 'package:wicchu/features/admin/page_appearance_editor.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/widgets/community_header_border.dart';
import 'package:wicchu/widgets/profile_accent_picker.dart';
import 'package:wicchu/widgets/profile_top_bar_glow.dart';
import 'package:wicchu/widgets/animated_neon_border.dart';

Future<Community> update(
  DemoCommunityRepository repository,
  Community community, {
  bool? enabled,
  String? accent,
  bool? neon,
}) => repository.updateCommunity(
  community,
  town: community.town,
  name: community.name,
  description: community.description,
  visibility: community.visibility,
  approvalRequired: community.approvalRequired,
  showWeather: community.showWeather,
  links: community.links,
  businessServices: community.businessServices,
  businessLocation: community.businessLocation,
  headerBorderEnabled: enabled,
  accentColor: accent,
  neonBordersEnabled: neon,
);

void main() {
  test(
    'contour meets the cover boundary and follows both existing cutouts',
    () {
      for (final height in [84.0, 158.0]) {
        for (final width in [320.0, 430.0, 800.0]) {
          final path = CommunityHeaderGeometry.boundary(
            Size(width, height),
            cutouts: true,
            membership: true,
          );
          final metric = path.computeMetrics().single;
          expect(
            metric.getTangentForOffset(0)!.position,
            Offset(0, height - 39),
          );
          expect(path.getBounds().top, closeTo(height - 78, .001));
          expect(
            metric.getTangentForOffset(metric.length)!.position.dx,
            closeTo(width, .001),
          );
          final withoutMembership = CommunityHeaderGeometry.boundary(
            Size(width, height),
            cutouts: true,
            membership: false,
          ).computeMetrics().single;
          expect(
            withoutMembership
                .getTangentForOffset(withoutMembership.length)!
                .position,
            Offset(width, height - 8),
          );
        }
      }
      final flat = CommunityHeaderGeometry.boundary(
        const Size(320, 150),
        cutouts: false,
        membership: false,
      ).computeMetrics().single;
      expect(flat.length, 320);
      expect(flat.getTangentForOffset(0)!.position, const Offset(0, 150));
    },
  );

  test('painter repaints only for appearance or geometry changes', () {
    final original = CommunityHeaderBorderPainter(
      color: profileAccentColor('teal'),
      cutouts: true,
      membership: true,
    );
    expect(original.shouldRepaint(original), isFalse);
    expect(
      CommunityHeaderBorderPainter(
        color: profileAccentColor('rose'),
        cutouts: true,
        membership: true,
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      CommunityHeaderBorderPainter(
        color: original.color,
        cutouts: true,
        membership: false,
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      CommunityHeaderBorderPainter(
        color: original.color,
        cutouts: false,
        membership: true,
      ).shouldRepaint(original),
      isTrue,
    );
  });

  testWidgets(
    'appearance hides decorative border and preserves its saved value',
    (tester) async {
      final repository = DemoCommunityRepository();
      final original = (await repository.listJoinedCommunities()).first;
      final community = await update(repository, original, enabled: true);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunitySettingsPage(
            repository: repository,
            community: community,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('appearance-color'));
      await tester.scrollUntilVisible(
        row,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('appearance-border')), findsNothing);
      expect(find.text('Decorative border'), findsNothing);
      final save = find.text('Save changes');
      await tester.scrollUntilVisible(
        save,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final saved = await repository.getCommunity(community.id);
      expect(saved.headerBorderEnabled, isTrue);
      expect(saved.accentColor, community.accentColor);
      final recolored = await update(repository, saved, accent: 'rose');
      expect(recolored.headerBorderEnabled, isTrue);
      final disabled = await update(repository, recolored, enabled: false);
      expect(disabled.headerBorderEnabled, isFalse);
      expect(disabled.accentColor, 'rose');
    },
  );

  testWidgets('neon editor links to color and back discards un-applied color', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: PageAppearanceEditor(
          section: PageAppearanceSection.neon,
          value: (
            accent: 'teal',
            neon: true,
            border: false,
            animation: NeonBorderAnimation.staticGlow,
            duration: 5.0,
          ),
        ),
      ),
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
    await tester.tap(find.text('Profile color'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-accent-green')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
    await tester.tap(find.text('Profile color'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-accent-green')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
    expect(find.text('Green'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'animation editor returns style and duration using top bar preview',
    (tester) async {
      PageAppearanceDraft? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await Navigator.push<PageAppearanceDraft>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PageAppearanceEditor(
                        section: PageAppearanceSection.neon,
                        value: (
                          accent: 'green',
                          neon: true,
                          border: true,
                          animation: NeonBorderAnimation.staticGlow,
                          duration: 5.0,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final animation in NeonBorderAnimation.values) {
        final choice = find.byKey(
          ValueKey('neon-animation-${animation.apiValue}'),
        );
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        final preview = tester.widget<ProfileTopBarGlow>(
          find.byType(ProfileTopBarGlow),
        );
        expect(preview.animation, animation);
        expect(
          tester
              .widget<AnimatedNeonBorder>(find.byType(AnimatedNeonBorder))
              .bottomEdgeOnly,
          isTrue,
        );
      }
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('neon-animation-duration')),
      );
      slider.onChanged!(8);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.animation, NeonBorderAnimation.aurora);
      expect(result!.duration, 8);
      expect(result!.border, isTrue);
    },
  );

  for (final category in [
    ProfileCategory.localBusiness,
    ProfileCategory.organization,
    ProfileCategory.person,
    ProfileCategory.creator,
  ]) {
    testWidgets('$category uses the shared community header layout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = DemoCommunityRepository();
      final created = await repository.createCommunity(
        CreateCommunityInput(
          name: 'Public page',
          description: 'About this page',
          town: const Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          categoryNames: ['Posts'],
          type: CommunityType.publicProfile,
          profileCategory: category,
        ),
      );
      final community = await update(
        repository,
        created,
        enabled: true,
        accent: 'blue',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final border = tester.widget<CommunityHeaderBorder>(
        find.byType(CommunityHeaderBorder),
      );
      expect(border.cutouts, isTrue);
      expect(border.membership, isTrue);
      expect(border.color, profileAccentColor('blue'));
      expect(
        find.byKey(const ValueKey('community-membership-backing')),
        findsOneWidget,
      );
      final visitor = Community(
        id: community.id,
        name: community.name,
        description: community.description,
        shortDescription: 'A short introduction',
        town: community.town,
        visibility: community.visibility,
        createdBy: community.createdBy,
        createdAt: community.createdAt,
        type: CommunityType.publicProfile,
        profileCategory: category,
        accentColor: 'blue',
        headerBorderEnabled: true,
      );
      await update(repository, visitor, enabled: true);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            key: UniqueKey(),
            community: visitor,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('header-follow-action')),
        findsOneWidget,
      );
      expect(find.text('A short introduction'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('header-follow-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-role-badge')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'neon stays on the top bar independently of the decorative border',
    (tester) async {
      final repository = DemoCommunityRepository();
      var community = (await repository.listJoinedCommunities()).first;
      Future<void> show() async {
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              key: UniqueKey(),
              community: community,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final neon in [false, true]) {
        community = await update(
          repository,
          community,
          accent: 'neon_cyan',
          enabled: true,
          neon: neon,
        );
        await show();
        final border = tester.widget<CommunityHeaderBorder>(
          find.byType(CommunityHeaderBorder),
        );
        expect(border.color, profileAccentColor('neon_cyan'));
        expect(border.glow, isEmpty);
        expect(
          find.byType(ProfileTopBarGlow),
          neon ? findsOneWidget : findsNothing,
        );
        expect(
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey('community-avatar-backing')),
                  )
                  .decoration
              is BoxDecoration,
          isTrue,
        );
        final decoration =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('community-avatar-backing')),
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.boxShadow, isNull);
        final painter = CommunityHeaderBorderPainter(
          color: border.color,
          cutouts: true,
          membership: true,
          glow: border.glow,
        );
        expect(
          painter.shouldRepaint(
            CommunityHeaderBorderPainter(
              color: border.color,
              cutouts: true,
              membership: true,
            ),
          ),
          isFalse,
        );
      }
      community = await update(repository, community, enabled: false);
      await show();
      expect(find.byType(CommunityHeaderBorder), findsNothing);
      expect(community.neonBordersEnabled, isTrue);
      expect(find.byType(ProfileTopBarGlow), findsOneWidget);
      expect(community.accentColor, 'neon_cyan');
      community = await update(
        repository,
        community,
        enabled: true,
        accent: 'teal',
      );
      await show();
      expect(
        tester
            .widget<CommunityHeaderBorder>(find.byType(CommunityHeaderBorder))
            .glow,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'header inherits accent without moving content in $brightness',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = DemoCommunityRepository();
        var community = (await repository.listJoinedCommunities()).first;
        Future<void> show() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: CommunityProfilePage(
                key: UniqueKey(),
                community: community,
                repository: repository,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show();
        expect(find.byType(CommunityHeaderBorder), findsNothing);
        final avatar = tester.getRect(
          find.byKey(const ValueKey('community-avatar-backing')),
        );
        final membership = tester.getRect(
          find.byKey(const ValueKey('community-membership-backing')),
        );
        for (final accent in ['purple', 'rose']) {
          community = await update(
            repository,
            community,
            enabled: true,
            accent: accent,
          );
          await show();
          expect(
            tester
                .widget<CommunityHeaderBorder>(
                  find.byType(CommunityHeaderBorder),
                )
                .color,
            profileAccentColor(accent),
          );
          expect(
            tester.getRect(
              find.byKey(const ValueKey('community-avatar-backing')),
            ),
            avatar,
          );
          expect(
            tester.getRect(
              find.byKey(const ValueKey('community-membership-backing')),
            ),
            membership,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
