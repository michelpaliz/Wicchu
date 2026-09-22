import 'package:flutter/material.dart';
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

    expect(find.text('Wicchu'), findsOneWidget);
    expect(find.text('Your communities'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('opens a community and its prominent categories', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Town X Community').first);
    await tester.pumpAndSettle();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Latest posts'), findsOneWidget);
  });

  testWidgets('creates a community from the profile', (tester) async {
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

    final repository = DemoCommunityRepository();
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

    await tester.tap(find.text('Town X Community').first);
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

    await tester.tap(find.text('EN').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(find.text('Tus comunidades'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
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
    expect(find.text('1 comunidad · 0 publicaciones'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cerrar sesión'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ES').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Your communities'), findsOneWidget);
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

    await tester.tap(find.text('Town X Community').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Administrar comunidad'));
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
