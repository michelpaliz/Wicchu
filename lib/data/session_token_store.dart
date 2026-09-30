import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists authentication tokens using storage supported by each platform.
///
/// flutter_secure_storage relies on Web Crypto in browsers, which can leave a
/// partially readable session in some browser/privacy configurations. Web
/// sessions already use short-lived access tokens, so browser preferences are
/// used there while native apps retain encrypted platform storage.
class SessionTokenStore {
  SessionTokenStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  Future<String?> read(String key) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(key);
    }
    return _secureStorage.read(key: key);
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }
}
