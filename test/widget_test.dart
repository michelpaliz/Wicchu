import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/auth_gateway.dart';
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
  Future<void> signOut() async {}
}

void main() {
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

  testWidgets('offers Facebook registration when signed out', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Facebook'), findsOneWidget);
  });
}
