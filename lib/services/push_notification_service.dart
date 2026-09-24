import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../domain/community_repository.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  final _receivedController = StreamController<Map<String, dynamic>>.broadcast();
  bool _active = false;
  String? _currentToken;
  String _languageCode = 'en';

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  bool get isConfigured =>
      !kIsWeb ||
      (_apiKey.isNotEmpty &&
          _appId.isNotEmpty &&
          _senderId.isNotEmpty &&
          _projectId.isNotEmpty);
  Stream<Map<String, dynamic>> get received => _receivedController.stream;

  Future<void> activate(
    CommunityRepository repository, {
    required String languageCode,
    required void Function(Map<String, dynamic> data) onTap,
    void Function(String message, Map<String, dynamic> data)? onForeground,
  }) async {
    if (_active || !isConfigured) return;
    _languageCode = languageCode == 'es' ? 'es' : 'en';
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _senderId,
              projectId: _projectId,
            ),
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await repository.registerDeviceToken(
          token,
          platform: _platform,
          languageCode: _languageCode,
        );
      }
      _tokenSubscription = messaging.onTokenRefresh.listen(
        (token) {
          _currentToken = token;
          repository.registerDeviceToken(
            token,
            platform: _platform,
            languageCode: _languageCode,
          );
        },
      );
      _tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => onTap(message.data),
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        _receivedController.add(message.data);
        onForeground?.call(
          message.notification?.body ?? 'New activity on Wicchu',
          message.data,
        );
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) onTap(initial.data);
      _active = true;
    } catch (error) {
      debugPrint('Wicchu push notifications unavailable: $error');
    }
  }

  Future<void> updateLanguage(
    CommunityRepository repository,
    String languageCode,
  ) async {
    _languageCode = languageCode == 'es' ? 'es' : 'en';
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    await repository.registerDeviceToken(
      token,
      platform: _platform,
      languageCode: _languageCode,
    );
  }

  String get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'web',
  };

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _tapSubscription?.cancel();
    await _foregroundSubscription?.cancel();
  }
}
