# Wicchu

Flutter client for the Wicchu local-community platform.

## Targets

- Android
- iOS
- Web

## Development

```bash
flutter pub get
flutter run
```

For a local UI preview without signing in or calling the backend, run `flutter run -t lib/main_preview.dart`. Preview communities exist only in memory.

The community backend is exposed under `/api/community/v1` on the shared Hexora server.

The current UI gaps and proposed backend contract are documented in [BACKEND_REQUIREMENTS.md](BACKEND_REQUIREMENTS.md).

## Facebook login configuration

Create a Meta application with Android package `com.wicchu.wicchu` and iOS bundle ID `com.wicchu.wicchu`.

- Backend: set `FACEBOOK_APP_ID` and `FACEBOOK_APP_SECRET`.
- Android: set `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN` in the user or CI Gradle properties.
- iOS: replace the placeholder Facebook values in `ios/Flutter/Debug.xcconfig` and `Release.xcconfig` through deployment configuration.
- Web: build with `--dart-define=FACEBOOK_APP_ID=... --dart-define=FACEBOOK_GRAPH_VERSION=...`.
- All clients: set the backend origin with `--dart-define=API_BASE_URL=https://your-api.example` when it differs from `https://hexora.dev`.

Never put `FACEBOOK_APP_SECRET` in the Flutter application.

For Android signing certificates and Meta key hashes, see [FACEBOOK_LOGIN_REQUIREMENTS.md](FACEBOOK_LOGIN_REQUIREMENTS.md).
