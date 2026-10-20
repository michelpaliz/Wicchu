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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Wicchu',
      packageName: 'com.wicchu.wicchu',
      version: '1.0.1',
      buildNumber: '28',
      buildSignature: '',
    );
  });

  test('failed checks retry immediately and preserve cached policy', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_update_cached_policy',
      '{"updateAvailable":false}',
    );
    var calls = 0;
    final service = AppUpdateService(
      client: MockClient((_) async {
        calls++;
        return http.Response('unavailable', 503);
      }),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(service.check(languageCode: 'en'), throwsStateError);
    }
    expect(calls, 2);
    expect(prefs.getString('app_update_last_check'), isNull);
    expect(
      prefs.getString('app_update_cached_policy'),
      '{"updateAvailable":false}',
    );
  });

  test('malformed policies do not start cooldown', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    for (final body in [
      'not json',
      '{}',
      '{"updateAvailable":true,"updateUrl":"http://bad"}',
    ]) {
      final service = AppUpdateService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(service.check(languageCode: 'en'), throwsStateError);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'app_update_last_check',
        ),
        isNull,
      );
    }
  });

  test(
    'manual check bypasses cooldown and can detect a newly available update',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var calls = 0;
      final service = AppUpdateService(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode(
              calls == 1
                  ? {'updateAvailable': false}
                  : {
                      'updateAvailable': true,
                      'latestVersion': '1.0.2',
                      'latestBuild': 29,
                      'updateUrl': 'https://apps.apple.com/app/wicchu',
                    },
            ),
            200,
          );
        }),
      );
      expect(await service.check(languageCode: 'en'), isNull);
      expect(await service.check(languageCode: 'en'), isNull);
      expect(calls, 1);
      expect(
        (await service.check(languageCode: 'en', force: true))?.latestBuild,
        29,
      );
      expect(calls, 2);
    },
  );

  test('Android retries if both backend and Google Play fail', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = AppUpdateService(
      client: MockClient((_) async => http.Response('', 503)),
      checkGooglePlay: () async => throw StateError('Play unavailable'),
    );
    await expectLater(service.check(languageCode: 'en'), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'app_update_last_check',
      ),
      isNull,
    );
  });

  test(
    'installing a new build invalidates a cached mandatory update',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var calls = 0;
      final service = AppUpdateService(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode(
              calls == 1
                  ? {
                      'updateAvailable': true,
                      'updateRequired': true,
                      'latestVersion': '1.0.2',
                      'latestBuild': 29,
                      'updateUrl': 'https://apps.apple.com/app/wicchu',
                    }
                  : {'updateAvailable': false},
            ),
            200,
          );
        }),
      );
      expect((await service.check(languageCode: 'en'))?.required, isTrue);
      expect((await service.check(languageCode: 'en'))?.required, isTrue);
      expect(calls, 1);
      PackageInfo.setMockInitialValues(
        appName: 'Wicchu',
        packageName: 'com.wicchu.wicchu',
        version: '1.0.2',
        buildNumber: '29',
        buildSignature: '',
      );
      expect(await service.check(languageCode: 'en'), isNull);
      expect(calls, 2);
    },
  );

  test('corrupt cached policy triggers a fresh check', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({
      'app_update_checked_package': 'ios:1.0.1:28',
      'app_update_last_check': DateTime.now().toIso8601String(),
      'app_update_cached_policy': 'broken json',
    });
    var calls = 0;
    final service = AppUpdateService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{"updateAvailable":false}', 200);
      }),
    );
    expect(await service.check(languageCode: 'en'), isNull);
    expect(calls, 1);
  });

  test('future check timestamps do not suppress new checks', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({
      'app_update_checked_package': 'ios:1.0.1:28',
      'app_update_last_check': DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String(),
    });
    var calls = 0;
    final service = AppUpdateService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{"updateAvailable":false}', 200);
      }),
    );
    expect(await service.check(languageCode: 'en'), isNull);
    expect(calls, 1);
  });

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
