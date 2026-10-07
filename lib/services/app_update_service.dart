import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.required,
    required this.updateUrl,
    required this.releaseNotes,
  });

  final String latestVersion;
  final int latestBuild;
  final bool required;
  final String updateUrl;
  final String releaseNotes;

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
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    await preferences.setString(_lastCheckKey, now.toIso8601String());
    await preferences.setString(_cachedPolicyKey, jsonEncode(decoded));
    return AppUpdateInfo.fromJson(decoded);
  }
}
