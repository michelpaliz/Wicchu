import 'widgets/app_update_dialog.dart';
import 'widgets/app_update_scope.dart';
import 'features/onboarding/preferences_page.dart';
import 'widgets/wicchu_viewport.dart';
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/facebook_auth_gateway.dart';
import 'data/http_community_repository.dart';
import 'domain/auth_gateway.dart';
import 'domain/community_repository.dart';
import 'features/auth/login_page.dart';
import 'features/main/main_shell.dart';
import 'features/community/shared_post_page.dart';
import 'features/chat/direct_chat_pages.dart';
import 'features/community/community_invitations_page.dart';
import 'features/community/community_profile_page.dart';
import 'features/promotions/promotions_page.dart';
import 'localization/app_language.dart';
import 'theme/theme_menu.dart';
import 'theme/wicchu_theme.dart';
import 'services/push_notification_service.dart';
import 'services/presence_service.dart';
import 'services/app_update_service.dart';
import 'services/analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AnalyticsService.instance.initialize();
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
    this.updateService,
  });

  final CommunityRepository repository;
  final AuthGateway authGateway;
  final AppUpdateService? updateService;

  @override
  State<WicchuApp> createState() => _WicchuAppState();
}

class _WicchuAppState extends State<WicchuApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingPostId;
  String? _pendingCommunityId;
  bool _pendingInvitations = false;
  String? _pendingInvitationToken;
  bool _pendingPromotions = false;
  String? _pendingChatSenderId;
  late Future<bool> _hasSession;
  String _languageCode = 'en';
  bool _preferencesLoaded = false;
  bool _preferencesCompleted = false;
  bool _languageChangedByUser = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _themeChangedByUser = false;
  bool _pushActivationStarted = false;
  late final _appUpdateService = widget.updateService ?? AppUpdateService();
  bool _checkingForUpdate = false;
  Future<AppUpdateInfo?>? _pendingUpdateLookup;
  bool _updateDialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _languageCode =
        WidgetsBinding.instance.platformDispatcher.locales
            .map((locale) => locale.languageCode)
            .where((code) => code == 'es' || code == 'en')
            .firstOrNull ??
        'en';
    _hasSession = widget.authGateway.hasSession();
    _loadPreferences();
    _listenForLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    PushNotificationService.instance.dispose();
    PresenceService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForAppUpdate();
  }

  void _updateFeedback(String message) {
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(context.tr(message))),
    );
  }

  Future<void> _checkForAppUpdate({bool manual = false}) async {
    if (manual && _checkingForUpdate && !_updateDialogVisible) {
      try {
        await _pendingUpdateLookup;
      } catch (_) {
        // The explicit request should still retry after an automatic failure.
      }
    }
    if (!_preferencesCompleted ||
        _checkingForUpdate ||
        _updateDialogVisible ||
        !mounted) {
      return;
    }
    _checkingForUpdate = true;
    try {
      _pendingUpdateLookup = _appUpdateService.check(
        languageCode: _languageCode,
        force: manual,
      );
      final update = await _pendingUpdateLookup;
      if (!mounted) return;
      if (update == null) {
        if (manual) _updateFeedback('Wicchu is up to date.');
        return;
      }
      final dialogContext = _navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) return;
      _updateDialogVisible = true;
      await showDialog<void>(
        context: dialogContext,
        barrierDismissible: !update.required,
        builder: (context) => AppUpdateDialog(
          update: update,
          onUpdate: () async {
            final result = await _appUpdateService.install(update);
            if (result == AppUpdateActionResult.cancelled) return false;
            final opened =
                result == AppUpdateActionResult.success ||
                await launchUrl(
                  Uri.parse(update.updateUrl),
                  mode: LaunchMode.externalApplication,
                );
            if (!opened) throw StateError('Could not open the store.');
            return true;
          },
        ),
      );
    } on UnsupportedError {
      if (manual) {
        _updateFeedback('Update checks are available on Android and iOS.');
      }
    } catch (error) {
      if (manual) {
        _updateFeedback('Could not check for updates. Please try again.');
      }
      debugPrint('Wicchu update check unavailable: $error');
    } finally {
      _pendingUpdateLookup = null;
      _checkingForUpdate = false;
      _updateDialogVisible = false;
    }
  }

  void _activatePush() {
    if (_pushActivationStarted) return;
    _pushActivationStarted = true;
    PushNotificationService.instance.activate(
      widget.repository,
      languageCode: _languageCode,
      onTap: (data) {
        final type = data['type']?.toString() ?? '';
        if (type == 'direct_message') {
          final senderId = data['senderId']?.toString();
          if (senderId?.isNotEmpty == true && mounted) {
            setState(() => _pendingChatSenderId = senderId);
            _openPendingPost();
          }
          return;
        }
        if (type.startsWith('promotion_')) {
          if (mounted) setState(() => _pendingPromotions = true);
          _openPendingPost();
          return;
        }
        final postId = data['postId']?.toString();
        const openableTypes = {
          'post_reaction',
          'comment_reaction',
          'post_comment',
          'comment_reply',
          'post_approved',
          'post_restored',
          'comment_approved',
        };
        if (openableTypes.contains(type) &&
            postId != null &&
            postId.isNotEmpty) {
          _queueLink(Uri(scheme: 'wicchu', host: 'posts', path: postId));
          _openPendingPost();
        }
      },
      onForeground: (message, data) {
        const openableTypes = {
          'post_reaction',
          'comment_reaction',
          'post_comment',
          'comment_reply',
          'post_approved',
          'post_restored',
          'comment_approved',
          'report_created',
        };
        final type = data['type']?.toString() ?? '';
        final postId = data['postId']?.toString();
        final senderId = data['senderId']?.toString();
        final canOpenChat =
            type == 'direct_message' && senderId?.isNotEmpty == true;
        final canOpenPost =
            openableTypes.contains(type) && postId?.isNotEmpty == true;
        _scaffoldMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              action: !canOpenChat && !canOpenPost
                  ? null
                  : SnackBarAction(
                      label: 'View',
                      onPressed: () {
                        if (canOpenChat) {
                          setState(() => _pendingChatSenderId = senderId);
                          _openPendingPost();
                          return;
                        }
                        _queueLink(
                          Uri(scheme: 'wicchu', host: 'posts', path: postId!),
                        );
                        _openPendingPost();
                      },
                    ),
            ),
          );
      },
    );
  }

  Future<void> _listenForLinks() async {
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) _queueLink(initial);
      _linkSubscription = links.uriLinkStream.listen((uri) {
        _queueLink(uri);
        _openPendingPost();
      });
    } catch (_) {
      // Deep links are unavailable on unsupported platforms and in widget tests.
    }
  }

  void _queueLink(Uri uri) {
    final invitationToken = _invitationTokenFromUri(uri);
    if (invitationToken != null) {
      if (mounted) setState(() => _pendingInvitationToken = invitationToken);
      return;
    }
    if ((uri.scheme == 'wicchu' && uri.host == 'invitations') ||
        ((uri.scheme == 'http' || uri.scheme == 'https') &&
            _isWicchuWebHost(uri.host) &&
            uri.pathSegments.length >= 2 &&
            uri.pathSegments[0] == 'wicchu' &&
            uri.pathSegments[1] == 'invitations')) {
      if (mounted) setState(() => _pendingInvitations = true);
      return;
    }
    final postId = _postIdFromUri(uri);
    if (postId != null && mounted) {
      setState(() => _pendingPostId = postId);
      return;
    }
    final communityId = _communityIdFromUri(uri);
    if (communityId != null && mounted) {
      setState(() => _pendingCommunityId = communityId);
    }
  }

  String? _invitationTokenFromUri(Uri uri) {
    if (uri.scheme == 'wicchu' &&
        uri.host == 'invitations' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'link') {
      return uri.pathSegments[1];
    }
    final segments = uri.pathSegments;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        _isWicchuWebHost(uri.host) &&
        segments.length >= 4 &&
        segments[0] == 'wicchu' &&
        segments[1] == 'invitations' &&
        segments[2] == 'link') {
      return segments[3];
    }
    return null;
  }

  String? _postIdFromUri(Uri uri) {
    if (uri.scheme == 'wicchu' &&
        uri.host == 'posts' &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final segments = uri.pathSegments;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        _isWicchuWebHost(uri.host) &&
        segments.length >= 3 &&
        segments[0] == 'wicchu' &&
        segments[1] == 'posts') {
      return segments[2];
    }
    return null;
  }

  String? _communityIdFromUri(Uri uri) {
    if (uri.scheme == 'wicchu' &&
        uri.host == 'communities' &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    final segments = uri.pathSegments;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        _isWicchuWebHost(uri.host) &&
        segments.length >= 3 &&
        segments[0] == 'wicchu' &&
        segments[1] == 'communities') {
      return segments[2];
    }
    return null;
  }

  bool _isWicchuWebHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'wicchu.com' ||
        normalized == 'www.wicchu.com' ||
        normalized == 'hexora.dev' ||
        normalized == 'www.hexora.dev';
  }

  void _openPendingPost() {
    if (!_preferencesCompleted) return;
    final chatSenderId = _pendingChatSenderId;
    if (chatSenderId != null) {
      _pendingChatSenderId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final conversation = await widget.repository.startDirectConversation(
            chatSenderId,
          );
          if (!mounted) return;
          await _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => DirectChatPage(
                repository: widget.repository,
                conversation: conversation,
              ),
            ),
          );
        } catch (error) {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      });
      return;
    }
    final communityId = _pendingCommunityId;
    if (communityId != null) {
      _pendingCommunityId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final community = await widget.repository.getCommunity(communityId);
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CommunityProfilePage(
                community: community,
                repository: widget.repository,
              ),
            ),
          );
        } catch (error) {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      });
      return;
    }
    final invitationToken = _pendingInvitationToken;
    if (invitationToken != null) {
      _pendingInvitationToken = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CommunityInvitationLinkPage(
              token: invitationToken,
              repository: widget.repository,
            ),
          ),
        );
      });
      return;
    }
    if (_pendingInvitations) {
      _pendingInvitations = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                MyCommunityInvitationsPage(repository: widget.repository),
          ),
        );
      });
      return;
    }
    if (_pendingPromotions) {
      _pendingPromotions = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => PromotionsPage(repository: widget.repository),
          ),
        );
      });
      return;
    }
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
        _preferencesCompleted =
            preferences.getBool('onboarding_preferences_completed') ?? false;
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
    } finally {
      if (mounted) setState(() => _preferencesLoaded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForAppUpdate());
    }
  }

  Future<void> _completePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final languageSaved = await preferences.setString(
      'language',
      _languageCode,
    );
    final themeSaved = await preferences.setString(
      'themeMode',
      _themeMode.name,
    );
    if (!languageSaved || !themeSaved) {
      throw StateError('Preferences not saved');
    }
    final completed = await preferences.setBool(
      'onboarding_preferences_completed',
      true,
    );
    if (!completed) throw StateError('Preferences not saved');
    if (!mounted) return;
    setState(() => _preferencesCompleted = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForAppUpdate());
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
    try {
      await PushNotificationService.instance.updateLanguage(
        widget.repository,
        code,
      );
    } catch (_) {
      // Local preferences remain available when device registration is offline.
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
          scaffoldMessengerKey: _scaffoldMessengerKey,
          title: 'Wicchu',
          navigatorObservers: AnalyticsService.instance.navigatorObservers,
          builder: (context, child) => AppUpdateScope(
            checkForUpdates: () => _checkForAppUpdate(manual: true),
            child: WicchuViewport(child: child ?? const SizedBox.shrink()),
          ),
          debugShowCheckedModeBanner: false,
          theme: WicchuTheme.light,
          darkTheme: WicchuTheme.dark,
          themeMode: _themeMode,
          locale: Locale(_languageCode),
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FutureBuilder<bool>(
            future: _hasSession,
            builder: (context, snapshot) {
              if (!_preferencesLoaded) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (!_preferencesCompleted) {
                return PreferencesPage(onContinue: _completePreferences);
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!) {
                _activatePush();
                PresenceService.instance.start();
                _openPendingPost();
                return MainShell(
                  repository: widget.repository,
                  authGateway: widget.authGateway,
                  onSignedOut: () {
                    unawaited(AnalyticsService.instance.identifyUser(null));
                    _navigatorKey.currentState?.popUntil(
                      (route) => route.isFirst,
                    );
                    setState(() {
                      _hasSession = Future.value(false);
                    });
                  },
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
