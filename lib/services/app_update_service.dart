import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart' as play;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NativeUpdateMode { none, flexible, immediate }

enum AppUpdateActionResult { success, cancelled, failed, notNative }

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.required,
    required this.updateUrl,
    required this.releaseNotes,
    this.nativeMode = NativeUpdateMode.none,
  });

  final String latestVersion;
  final int latestBuild;
  final bool required;
  final String updateUrl;
  final String releaseNotes;
  final NativeUpdateMode nativeMode;

  bool get usesGooglePlay => nativeMode != NativeUpdateMode.none;

  static AppUpdateInfo? fromJson(Map<String, dynamic> json) {
    if (json['updateAvailable'] != true) return null;
    final updateUrl = json['updateUrl']?.toString() ?? '';
    final uri = Uri.tryParse(updateUrl);
    if (uri == null || uri.scheme != 'https') return null;
    return AppUpdateInfo(
      latestVersion: json['latestVersion']?.toString() ?? '',
      latestBuild: (json['latestBuild'] as num?)?.toInt() ?? 0,
      required: json['updateRequired'] == true,
      updateUrl: updateUrl,
      releaseNotes: json['releaseNotes']?.toString() ?? '',
    );
  }
}

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Future<play.AppUpdateInfo> Function()? checkGooglePlay,
  }) : _client = client ?? http.Client(),
       _checkGooglePlay = checkGooglePlay ?? play.InAppUpdate.checkForUpdate;

  final http.Client _client;
  final Future<play.AppUpdateInfo> Function() _checkGooglePlay;

  static const _lastCheckKey = 'app_update_last_check';
  static const _cachedPolicyKey = 'app_update_cached_policy';
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hexora.dev',
  );

  Future<AppUpdateInfo?> check({required String languageCode}) async {
    if (kIsWeb) return null;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (platform == null) return null;

    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastCheck = DateTime.tryParse(
      preferences.getString(_lastCheckKey) ?? '',
    );
    if (lastCheck != null &&
        now.difference(lastCheck) < const Duration(days: 1)) {
      final cached = preferences.getString(_cachedPolicyKey);
      if (cached == null) return null;
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) return null;
      final info = AppUpdateInfo.fromJson(decoded);
      return info?.required == true ? info : null;
    }

    final package = await PackageInfo.fromPlatform();
    final uri = Uri.parse('$_apiBaseUrl/wicchu/app-update').replace(
      queryParameters: {
        'platform': platform,
        'version': package.version,
        'build': package.buildNumber,
        'language': languageCode == 'es' ? 'es' : 'en',
      },
    );
    Map<String, dynamic>? decoded;
    AppUpdateInfo? serverUpdate;
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final value = jsonDecode(response.body);
        if (value is Map<String, dynamic>) {
          decoded = value;
          serverUpdate = AppUpdateInfo.fromJson(value);
        }
      }
    } catch (error) {
      debugPrint('Wicchu server update policy unavailable: $error');
    }

    AppUpdateInfo? playUpdate;
    if (platform == 'android') {
      try {
        final info = await _checkGooglePlay();
        final available =
            info.updateAvailability ==
                play.UpdateAvailability.updateAvailable ||
            info.updateAvailability ==
                play.UpdateAvailability.developerTriggeredUpdateInProgress;
        if (available) {
          final required = serverUpdate?.required == true;
          final mode = required && info.immediateUpdateAllowed
              ? NativeUpdateMode.immediate
              : info.flexibleUpdateAllowed
              ? NativeUpdateMode.flexible
              : info.immediateUpdateAllowed
              ? NativeUpdateMode.immediate
              : NativeUpdateMode.none;
          playUpdate = AppUpdateInfo(
            latestVersion: '',
            latestBuild: info.availableVersionCode ?? 0,
            required: required,
            updateUrl:
                serverUpdate?.updateUrl ??
                'https://play.google.com/store/apps/details?id=com.wicchu.wicchu',
            releaseNotes: serverUpdate?.releaseNotes ?? '',
            nativeMode: mode,
          );
        }
      } catch (error) {
        // Google Play updates only work for builds installed through a Play
        // testing or production track. Keep the server policy as a fallback.
        debugPrint('Google Play update check unavailable: $error');
      }
    }

    await preferences.setString(_lastCheckKey, now.toIso8601String());
    if (decoded != null) {
      await preferences.setString(_cachedPolicyKey, jsonEncode(decoded));
    } else {
      await preferences.remove(_cachedPolicyKey);
    }
    return playUpdate ?? serverUpdate;
  }

  Future<AppUpdateActionResult> install(AppUpdateInfo update) async {
    if (!update.usesGooglePlay) return AppUpdateActionResult.notNative;
    try {
      final result = switch (update.nativeMode) {
        NativeUpdateMode.immediate =>
          await play.InAppUpdate.performImmediateUpdate(),
        NativeUpdateMode.flexible =>
          await play.InAppUpdate.startFlexibleUpdate(),
        NativeUpdateMode.none => null,
      };
      if (result == null) return AppUpdateActionResult.notNative;
      if (result == play.AppUpdateResult.userDeniedUpdate) {
        return AppUpdateActionResult.cancelled;
      }
      if (result != play.AppUpdateResult.success) {
        return AppUpdateActionResult.failed;
      }
      if (update.nativeMode == NativeUpdateMode.flexible) {
        await play.InAppUpdate.completeFlexibleUpdate();
      }
      return AppUpdateActionResult.success;
    } catch (error) {
      debugPrint('Google Play update failed: $error');
      return AppUpdateActionResult.failed;
    }
  }
}
