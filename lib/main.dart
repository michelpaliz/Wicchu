import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/facebook_auth_gateway.dart';
import 'data/http_community_repository.dart';
import 'domain/auth_gateway.dart';
import 'domain/community_repository.dart';
import 'features/auth/login_page.dart';
import 'features/main/main_shell.dart';
import 'features/community/shared_post_page.dart';
import 'localization/app_language.dart';
import 'theme/theme_menu.dart';
import 'theme/wicchu_theme.dart';

void main() {
  runApp(
    WicchuApp(
      repository: HttpCommunityRepository(),
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
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingPostId;
  late Future<bool> _hasSession;
  String _languageCode = 'en';
  bool _languageChangedByUser = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _themeChangedByUser = false;

  @override
  void initState() {
    super.initState();
    _hasSession = widget.authGateway.hasSession();
    _loadPreferences();
    _listenForLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _listenForLinks() async {
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) _queueLink(initial);
      _linkSubscription = links.uriLinkStream.listen(_queueLink);
    } catch (_) {
      // Deep links are unavailable on unsupported platforms and in widget tests.
    }
  }

  void _queueLink(Uri uri) {
    final postId = _postIdFromUri(uri);
    if (postId == null || !mounted) return;
    setState(() => _pendingPostId = postId);
  }

  String? _postIdFromUri(Uri uri) {
    if (uri.scheme == 'wicchu' &&
        uri.host == 'posts' &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final segments = uri.pathSegments;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host == 'hexora.dev' &&
        segments.length >= 3 &&
        segments[0] == 'wicchu' &&
        segments[1] == 'posts') {
      return segments[2];
    }
    return null;
  }

  void _openPendingPost() {
    final postId = _pendingPostId;
    if (postId == null) return;
    _pendingPostId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) =>
              SharedPostPage(postId: postId, repository: widget.repository),
        ),
      );
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedLanguage = preferences.getString('language');
      final savedTheme = preferences.getString('themeMode');
      if (!mounted) return;
      setState(() {
        if (!_languageChangedByUser &&
            (savedLanguage == 'en' || savedLanguage == 'es')) {
          _languageCode = savedLanguage!;
        }
        if (!_themeChangedByUser) {
          _themeMode = switch (savedTheme) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
        }
      });
    } catch (_) {
      // Keep the current choices when local preferences are unavailable.
    }
  }

  Future<void> _setLanguage(String code) async {
    if (code != 'en' && code != 'es') return;
    _languageChangedByUser = true;
    setState(() => _languageCode = code);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('language', code);
    } catch (_) {
      // The selected language still applies for this session.
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    _themeChangedByUser = true;
    setState(() => _themeMode = mode);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('themeMode', mode.name);
    } catch (_) {
      // The selected theme still applies for this session.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      themeMode: _themeMode,
      onThemeChanged: _setThemeMode,
      child: AppLanguageScope(
        languageCode: _languageCode,
        onLanguageChanged: _setLanguage,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Wicchu',
          debugShowCheckedModeBanner: false,
          theme: WicchuTheme.light,
          darkTheme: WicchuTheme.dark,
          themeMode: _themeMode,
          locale: Locale(_languageCode),
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FutureBuilder<bool>(
            future: _hasSession,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!) {
                _openPendingPost();
                return MainShell(
                  repository: widget.repository,
                  authGateway: widget.authGateway,
                  onSignedOut: () => setState(() {
                    _hasSession = Future.value(false);
                  }),
                );
              }
              return LoginPage(
                authGateway: widget.authGateway,
                onSignedIn: () => setState(() {
                  _hasSession = Future.value(true);
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
