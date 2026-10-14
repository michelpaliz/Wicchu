import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_update/in_app_update.dart' as play;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/services/app_update_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('maps an optional application update', () {
    final update = AppUpdateInfo.fromJson({
      'updateAvailable': true,
      'updateRequired': false,
      'latestVersion': '1.1.0',
      'latestBuild': 20,
      'updateUrl': 'https://play.google.com/store/apps/details?id=wicchu',
      'releaseNotes': 'New messaging experience',
    });

    expect(update, isNotNull);
    expect(update!.required, isFalse);
    expect(update.latestVersion, '1.1.0');
    expect(update.latestBuild, 20);
  });

  test('rejects unavailable updates and unsafe links', () {
    expect(
      AppUpdateInfo.fromJson({
        'updateAvailable': false,
        'updateUrl': 'https://wicchu.com/download',
      }),
      isNull,
    );
    expect(
      AppUpdateInfo.fromJson({
        'updateAvailable': true,
        'updateUrl': 'http://untrusted.example/update',
      }),
      isNull,
    );
  });

  test('detects a normal Android update directly from Google Play', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Wicchu',
      packageName: 'com.wicchu.wicchu',
      version: '1.0.0',
      buildNumber: '13',
      buildSignature: '',
    );
    final service = AppUpdateService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'updateAvailable': false,
            'updateRequired': false,
            'latestVersion': '1.0.0',
            'latestBuild': 13,
            'updateUrl':
                'https://play.google.com/store/apps/details?id=com.wicchu.wicchu',
          }),
          200,
        ),
      ),
      checkGooglePlay: () async => play.AppUpdateInfo(
        updateAvailability: play.UpdateAvailability.updateAvailable,
        immediateUpdateAllowed: true,
        immediateAllowedPreconditions: const [],
        flexibleUpdateAllowed: true,
        flexibleAllowedPreconditions: const [],
        availableVersionCode: 20,
        installStatus: play.InstallStatus.unknown,
        packageName: 'com.wicchu.wicchu',
        clientVersionStalenessDays: 1,
        updatePriority: 0,
      ),
    );

    final update = await service.check(languageCode: 'en');

    expect(update, isNotNull);
    expect(update!.latestBuild, 20);
    expect(update.usesGooglePlay, isTrue);
    expect(update.nativeMode, NativeUpdateMode.flexible);
    expect(update.required, isFalse);
  });
}
