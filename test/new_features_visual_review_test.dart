import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/local_discovery_view.dart';
import 'package:wicchu/features/community/post_share.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

class _ReviewRepository extends DemoCommunityRepository {
  static const town = Town(
    id: 'echeandia',
    name: 'Echeandía',
    countryCode: 'EC',
  );

  final pages = [
    Community(
      id: 'restaurant',
      name: 'Como en Casa',
      description: 'Comida local',
      town: town,
      visibility: CommunityVisibility.public,
      createdBy: 'owner-1',
      createdAt: DateTime.utc(2026),
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.localBusiness,
      businessServices: const [BusinessService.food],
    ),
    Community(
      id: 'organization',
      name: 'Fundación Echeandía',
      description: 'Servicios para la comunidad',
      town: town,
      visibility: CommunityVisibility.public,
      createdBy: 'owner-2',
      createdAt: DateTime.utc(2026),
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.organization,
    ),
    Community(
      id: 'origin',
      name: 'Echeandía',
      description: 'Comunidad de origen',
      town: town,
      visibility: CommunityVisibility.public,
      createdBy: 'owner-3',
      createdAt: DateTime.utc(2026),
      myRole: CommunityRole.member,
    ),
    Community(
      id: 'destination',
      name: 'Dénia',
      description: 'Comunidad de destino',
      town: town,
      visibility: CommunityVisibility.public,
      createdBy: 'owner-4',
      createdAt: DateTime.utc(2026),
      myRole: CommunityRole.member,
    ),
  ];

  @override
  Future<List<Town>> listTowns() async => const [town];

  @override
  Future<List<Community>> listCommunities({
    String? query,
    String? townId,
  }) async => pages;

  @override
  Future<List<Community>> listLocalBusinesses({
    String? townId,
    String? query,
  }) async => pages;

  @override
  Future<List<CommunityPost>> listBusinessPosts(
    List<String> businessIds, {
    String? query,
  }) async => const [];

  @override
  Future<List<CommunityPost>> listLocalBusinessPosts(
    String townId, {
    String? query,
  }) async => const [];

  @override
  Future<List<CommunityCategory>> listCategories(String id) async => [
    CommunityCategory(
      id: 'general',
      communityId: id,
      name: 'General',
      icon: '💬',
    ),
  ];

  @override
  Future<CommunityRules> listRules(String id) async => const CommunityRules(
    rules: [],
    rulesVersion: 1,
    acceptedRulesVersion: 1,
    acceptanceRequired: false,
    canManage: false,
  );

  @override
  Future<List<CommunityShareResult>> sharePersonalPostToCommunities(
    String postId, {
    required Map<String, String> categoryByCommunity,
    String caption = '',
  }) async => const [
    CommunityShareResult(communityId: 'destination', status: 'published'),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('capture merged discovery and sharing features', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ReviewRepository();
    final boundary = GlobalKey();
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

    Future<void> open(Widget child, {double textScale = 1}) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: WicchuTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(body: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('/tmp/wicchu-new-features-review');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await open(LocalDiscoveryView(repository: repository));
    await shot('03-discovery-all');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Services'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Services'));
    await tester.pumpAndSettle();
    await shot('04-discovery-services');

    await open(
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => sharePostTo(
              context,
              repository,
              CommunityPost(
                id: 'post',
                communityId: 'origin',
                categoryId: 'general',
                authorId: 'owner-1',
                text: 'Publicación del restaurante',
                status: PostStatus.published,
                createdAt: DateTime.utc(2026),
                canShareToCommunities: true,
              ),
              PostShareDestination.community,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await shot('05-share-destinations');

    expect(find.text('Echeandía'), findsNothing);
    expect(find.text('Dénia'), findsOneWidget);
    await tester.tap(find.text('Dénia'));
    await tester.pumpAndSettle();
    await shot('06-share-selected');
    await tester.tap(find.text('Share to 1 community'));
    await tester.pumpAndSettle();
    await shot('07-share-result');

    await tester.tap(find.text('Done'));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await open(
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => sharePostTo(
              context,
              repository,
              CommunityPost(
                id: 'narrow-post',
                communityId: 'origin',
                categoryId: 'general',
                authorId: 'owner-1',
                text: 'Publicación de prueba',
                status: PostStatus.published,
                createdAt: DateTime.utc(2026),
                canShareToCommunities: true,
              ),
              PostShareDestination.community,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      textScale: 1.4,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await shot('08-narrow-large-text');
  });
}
