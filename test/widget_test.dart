import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/auth_gateway.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/create_community_page.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/main.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';
import 'package:wicchu/features/profile/edit_profile_links.dart';

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({required this.signedIn});
  final bool signedIn;

  @override
  Future<bool> hasSession() async => signedIn;

  @override
  Future<AuthSession> signInWithFacebook() async => const AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    userId: 'user-1',
    userName: 'test_user',
    isNewUser: true,
  );

  @override
  Future<AuthSession> signInWithGoogle() => signInWithFacebook();

  @override
  Future<void> signOut() async {}
}

class _RecordingRepository extends DemoCommunityRepository {
  String? lastSort;

  @override
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  }) {
    lastSort = sort;
    return super.listPosts(
      communityId,
      categoryId: categoryId,
      query: query,
      sort: sort,
    );
  }
}

class _NotificationsRepository extends DemoCommunityRepository {
  late String postId;
  bool read = false;

  @override
  Future<NotificationFeed> listNotifications() async => NotificationFeed(
    unreadCount: read ? 0 : 1,
    items: [
      CommunityNotification(
        id: 'notification-1',
        actorName: 'Alex',
        type: CommunityNotificationType.postComment,
        postId: postId,
        message: 'commented on your post',
        createdAt: DateTime.now(),
        isRead: read,
      ),
    ],
  );

  @override
  Future<void> markNotificationRead(String notificationId) async {
    read = true;
  }
}

class _EmptyTownsRepository extends DemoCommunityRepository {
  @override
  Future<List<Town>> listTowns() async => const [];
}

class _NoCommunitiesRepository extends DemoCommunityRepository {
  @override
  Future<List<Community>> listJoinedCommunities() async => [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the community-first home navigation', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wicchu'), findsNothing);
    expect(find.text('Town X Community'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('empty Home shows discovery and routes to Explore', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: _NoCommunitiesRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wicchu'), findsOneWidget);
    expect(find.text('Find your community'), findsOneWidget);
    expect(find.text('No posts found'), findsNothing);
    await tester.tap(find.text('Explore communities'));
    await tester.pumpAndSettle();
    expect(find.text('Town X Community'), findsWidgets);
  });

  testWidgets('multiple communities require a choice and persist it', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final second = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Second neighborhood',
        description: 'Nearby',
        town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select a community').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second neighborhood'));
    await tester.pumpAndSettle();
    expect(find.text('Second neighborhood'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'currentCommunityId:current-user',
      ),
      second.id,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Second neighborhood'), findsOneWidget);
  });

  testWidgets('logs out to the sign-in screen and can sign in again', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Log out'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Continue with Facebook'), findsOneWidget);

    await tester.tap(find.text('Continue with Facebook'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Town X Community'), findsOneWidget);
  });

  testWidgets('home uses the central post action across multiple towns', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'es'});
    final repository = DemoCommunityRepository();
    final community = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Echeandía',
        description: 'Comunidad local',
        town: Town(id: 'town-2', name: 'Echeandía', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    final category = (await repository.listCategories(community.id)).first;
    await repository.createPost(
      community.id,
      CreatePostInput(categoryId: category.id, text: 'Jornada de limpieza'),
    );

    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(CupertinoIcons.plus), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('Elige una comunidad'), findsOneWidget);
    await tester.tap(find.text('Echeandía').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Qué quieres publicar?'), findsOneWidget);
    await tester.tap(find.text('General').last);
    await tester.pumpAndSettle();
    expect(find.text('Crear publicación'), findsOneWidget);
  });

  testWidgets('account hub opens the canonical profile with owner editing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'es'});
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver mi perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberProfilePage), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfilePage), findsOneWidget);
  });

  testWidgets('another user profile hides edit controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(
          userId: 'another-user',
          repository: DemoCommunityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('translates the current user label on a post', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        supportedLocales: [Locale('en'), Locale('es')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: '💬',
            community: 'Echeandía',
            author: 'You',
            time: 'Hace 3 min',
            text: 'Jornada de limpieza',
          ),
        ),
      ),
    );
    expect(find.text('Tú'), findsOneWidget);
    expect(find.text('Hace 3 min · Echeandía'), findsOneWidget);
  });

  testWidgets('opens a community and its prominent categories', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Town X Community').first);
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Latest posts'), findsOneWidget);
    expect(find.text('Town X Community'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('New post'), findsOneWidget);
    expect(find.text('Community management'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('creates a community even when the town list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Create a community'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Create a community'));
    await tester.pumpAndSettle();

    expect(find.text('Create community'), findsOneWidget);
    expect(find.text('Community name'), findsOneWidget);

    final repository = _EmptyTownsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateCommunityPage(
          repository: repository,
          locateCurrentTown: () async =>
              const Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Community name'),
      'Riverside',
    );
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continue').at(step));
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create community').last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Your community is ready!'), findsOneWidget);
    await tester.tap(find.text('Enter community'));
    await tester.pumpAndSettle();
    expect(
      (await repository.listCommunities()).any(
        (item) => item.name == 'Riverside',
      ),
      isTrue,
    );
  });

  testWidgets('searches communities in Explore', (tester) async {
    final repository = DemoCommunityRepository();
    await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Riverside',
        description: 'Neighbors nearby',
        town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('📍 Explore communities'), findsOneWidget);
    expect(find.byTooltip('Use my location'), findsOneWidget);
    await tester.tap(find.byTooltip('Search communities'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Riverside');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Riverside'), findsWidgets);
    expect(find.text('Town X Community'), findsNothing);
  });

  testWidgets('requests popular category posts', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Town X Community').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('News').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('News').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();

    expect(repository.lastSort, 'popular');
  });

  testWidgets('opens a notification post and marks it read', (tester) async {
    final repository = _NotificationsRepository();
    final post = await repository.createPost(
      'town-x-community',
      const CreatePostInput(categoryId: 'category-0', text: 'Meeting tonight'),
    );
    repository.postId = post.id;
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex commented on your post'));
    await tester.pumpAndSettle();

    expect(repository.read, isTrue);
    expect(find.text('Meeting tonight'), findsOneWidget);
  });

  testWidgets('offers Facebook and Google registration when signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('switches between Spanish and English across the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('EN'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('EN').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    expect(find.text('Noticias'), findsOneWidget);

    final spanishContext = tester.element(find.text('Inicio'));
    expect(
      formatPostTime(
        spanishContext,
        DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      'Hace 3 min',
    );
    expect(
      spanishContext.trError(Exception('Server message without a translation')),
      'Ha ocurrido un error. Inténtalo de nuevo.',
    );
    await tester.tap(find.text('Tú').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 comunidad · 0 publicaciones'),
      -250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('1 comunidad · 0 publicaciones'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cerrar sesión'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tú').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ES').first);
    await tester.tap(find.text('ES').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('translates the admin review queue', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'es'});
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Town X Community').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrar comunidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denuncias'));
    await tester.pumpAndSettle();

    expect(find.text('No hay denuncias abiertas'), findsOneWidget);
  });

  testWidgets('changes and saves the appearance setting', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Appearance'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Appearance').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('themeMode'),
      'dark',
    );

    await tester.tap(find.byTooltip('Appearance').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });
}
