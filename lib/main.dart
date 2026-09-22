import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/facebook_auth_gateway.dart';
import 'data/http_community_repository.dart';
import 'domain/auth_gateway.dart';
import 'domain/community_repository.dart';
import 'features/auth/login_page.dart';
import 'features/main/main_shell.dart';
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
                return MainShell(
                  repository: widget.repository,
                  authGateway: widget.authGateway,
                  onSignedOut: () =>
                      setState(() => _hasSession = Future.value(false)),
                );
              }
              return LoginPage(
                authGateway: widget.authGateway,
                onSignedIn: () =>
                    setState(() => _hasSession = Future.value(true)),
              );
            },
          ),
        ),
      ),
    );
  }
}
