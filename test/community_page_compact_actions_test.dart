import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_page.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  testWidgets('community actions keep a compact visual hierarchy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _EmptyCommunityRepository();
    final community = (await repository.listManagedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        theme: WicchuTheme.light,
        home: CommunityPage(community: community, repository: repository),
      ),
    );
    await tester.pump();

    final publish = find.byKey(const ValueKey('new-community-post-action'));
    final profile = find.byKey(const ValueKey('view-community-profile-action'));
    final manage = find.byKey(const ValueKey('manage-community-action'));
    expect(publish, findsOneWidget);
    expect(profile, findsOneWidget);
    expect(manage, findsOneWidget);
    expect(tester.getSize(publish).height, 48);
    expect(tester.getSize(profile).height, 48);
    expect(tester.getSize(manage).height, 48);
    expect(tester.getTopLeft(profile).dy, tester.getTopLeft(manage).dy);
    expect(tester.getSize(profile).width, tester.getSize(manage).width);
    await tester.pumpAndSettle();
    expect(find.text('No posts yet.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('empty-posts-create-action')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty community profile uses one clear publication action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _EmptyCommunityRepository();
    final community = (await repository.listManagedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        theme: WicchuTheme.light,
        home: CommunityProfilePage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No posts yet.'), findsOneWidget);
    expect(find.text('No posts found'), findsNothing);
    expect(
      find.byKey(const ValueKey('empty-posts-create-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('community-composer-entry')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('community feed translates built-in categories and empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _EmptyCommunityRepository();
    final community = (await repository.listManagedCommunities()).first;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: WicchuTheme.light,
        home: CommunityProfilePage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Errores'), findsOneWidget);
    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('Aún no hay publicaciones.'), findsOneWidget);
    if (community.isGlobal) {
      expect(find.text('En cualquier lugar'), findsOneWidget);
      expect(find.text('Everywhere'), findsNothing);
    }
    expect(find.text('Bugs'), findsNothing);
    expect(find.text('Events'), findsNothing);
    expect(find.text('No posts yet.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyCommunityRepository extends DemoCommunityRepository {
  @override
  Future<List<CommunityCategory>> listCategories(String communityId) async => [
    CommunityCategory(
      id: 'general',
      communityId: communityId,
      name: 'General',
      icon: '💬',
    ),
    CommunityCategory(
      id: 'bugs',
      communityId: communityId,
      name: 'Bugs',
      icon: '🐛',
    ),
    CommunityCategory(
      id: 'events',
      communityId: communityId,
      name: 'Events',
      icon: '📅',
    ),
  ];

  @override
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  }) async => const [];
}
