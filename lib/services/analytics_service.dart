import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Privacy-conscious analytics for product decisions.
///
/// Events never include names, email addresses, post text, or precise
/// locations. Backend records remain the authority for business totals;
/// Firebase Analytics measures app usage and interaction funnels.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  List<NavigatorObserver> get navigatorObservers => [
    if (_analytics case final analytics?)
      FirebaseAnalyticsObserver(analytics: analytics),
  ];

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      _analytics = analytics;
      await analytics.logAppOpen();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Analytics initialization skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> identifyUser(String? userId) async {
    final normalized = userId?.trim();
    await _safely(
      () => _analytics?.setUserId(
        id: normalized == null || normalized.isEmpty ? null : normalized,
      ),
    );
  }

  Future<void> log(String name, {Map<String, Object>? parameters}) =>
      _safely(() => _analytics?.logEvent(name: name, parameters: parameters));

  Future<void> authenticationCompleted({
    required String provider,
    required String userId,
    required bool isNewUser,
  }) async {
    await identifyUser(userId);
    if (isNewUser) {
      await registrationCompleted(provider: provider);
    } else {
      await _safely(() => _analytics?.logLogin(loginMethod: provider));
    }
  }

  Future<void> registrationCompleted({required String provider}) async {
    await log('registration_completed', parameters: {'method': provider});
    await _safely(() => _analytics?.logSignUp(signUpMethod: provider));
  }

  Future<void> _safely(Future<void>? Function() action) async {
    try {
      await action();
    } catch (error) {
      if (kDebugMode) debugPrint('Analytics event skipped: $error');
    }
  }
}
