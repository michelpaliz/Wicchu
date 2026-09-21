import 'package:flutter/material.dart';

import 'data/demo_community_repository.dart';
import 'data/facebook_auth_gateway.dart';
import 'domain/auth_gateway.dart';
import 'domain/community_repository.dart';
import 'features/auth/login_page.dart';
import 'features/main/main_shell.dart';
import 'theme/wicchu_theme.dart';

void main() {
  runApp(
    WicchuApp(
      repository: DemoCommunityRepository(),
      authGateway: FacebookAuthGateway(),
    ),
  );
}

class WicchuApp extends StatefulWidget {
  const WicchuApp({
    super.key,
    required this.repository,
    required this.authGateway,
  });

  final CommunityRepository repository;
  final AuthGateway authGateway;

  @override
  State<WicchuApp> createState() => _WicchuAppState();
}

class _WicchuAppState extends State<WicchuApp> {
  late Future<bool> _hasSession;

  @override
  void initState() {
    super.initState();
    _hasSession = widget.authGateway.hasSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wicchu',
      debugShowCheckedModeBanner: false,
      theme: WicchuTheme.light,
      darkTheme: WicchuTheme.dark,
      themeMode: ThemeMode.system,
      home: FutureBuilder<bool>(
        future: _hasSession,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data!) {
            return MainShell(repository: widget.repository);
          }
          return LoginPage(
            authGateway: widget.authGateway,
            onSignedIn: () => setState(() => _hasSession = Future.value(true)),
          );
        },
      ),
    );
  }
}
