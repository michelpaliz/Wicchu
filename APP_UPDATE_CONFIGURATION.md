# App update notifications

Wicchu checks the public update policy when the mobile app opens or returns to the foreground. Successful checks are limited to once per day. Normal updates can be dismissed; builds below the configured minimum cannot dismiss the update screen.

Configure the backend separately for Android and iOS:

```env
WICCHU_ANDROID_LATEST_VERSION=1.0.1
WICCHU_ANDROID_LATEST_BUILD=14
WICCHU_ANDROID_MINIMUM_VERSION=1.0.0
WICCHU_ANDROID_MINIMUM_BUILD=13
WICCHU_ANDROID_UPDATE_URL=https://play.google.com/store/apps/details?id=com.wicchu.wicchu
WICCHU_ANDROID_RELEASE_NOTES_EN=Messaging and stability improvements.
WICCHU_ANDROID_RELEASE_NOTES_ES=Mejoras en mensajes y estabilidad.

WICCHU_IOS_LATEST_VERSION=1.0.1
WICCHU_IOS_LATEST_BUILD=14
WICCHU_IOS_MINIMUM_VERSION=1.0.0
WICCHU_IOS_MINIMUM_BUILD=13
WICCHU_IOS_UPDATE_URL=https://apps.apple.com/app/idYOUR_APP_ID
WICCHU_IOS_RELEASE_NOTES_EN=Messaging and stability improvements.
WICCHU_IOS_RELEASE_NOTES_ES=Mejoras en mensajes y estabilidad.
```

Release order:

1. Increment `version` and build number in `pubspec.yaml`.
2. Publish and verify the release in App Store Connect or Google Play.
3. Set the platform's latest version, build, store URL, and release notes.
4. Restart the backend with its updated environment.
5. Increase the minimum build only when older releases are unsafe or incompatible.

If no store URL is configured, the update button opens `https://wicchu.com/download`.
