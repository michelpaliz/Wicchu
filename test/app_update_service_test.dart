import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/services/app_update_service.dart';

void main() {
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
}
