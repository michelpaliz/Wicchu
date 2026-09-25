# Google Sign-In setup and troubleshooting

Wicchu uses Firebase/Google OAuth on Android and then sends the Google ID token to the Hexora backend. If the app shows **"Google sign-in is unavailable"** and the backend has no `POST /api/auth/google` request, the failure happened on the Android device before the server was contacted.

## Required identifiers

- Android package: `com.wicchu.wicchu`
- Firebase project: `wicchu-3ece7`
- Web OAuth client ID: `414702659593-94b8of4j0mgj16pr0r13a6a1dpm9mvpu.apps.googleusercontent.com`
- Configuration file location: `android/app/google-services.json`

Do not put a Google client secret in the Flutter application.

## Why the signing fingerprint matters

Google identifies an Android application using both its package name and the certificate that signed the APK or App Bundle. Debug keys are normally generated separately on every computer. Therefore, an APK built on another computer may have a different SHA-1 even when it uses the same repository and package name.

Every certificate used to distribute Wicchu must be registered in Firebase, including:

- The debug certificate from each development computer that builds installable APKs.
- The production upload/release certificate.
- The Google Play App Signing certificate when distributing through Google Play.

## Find the fingerprint used by a build

On the computer that builds the APK, run:

```bash
cd android
./gradlew signingReport
```

Find the installed build variant, usually `debug` or `release`, and copy its **SHA-1** and **SHA-256** values. Do not assume that another computer has the same debug fingerprint.

The development certificate configured on the Hexora server currently reports:

```text
SHA-1:   0A:AA:DF:2B:BA:F4:9C:85:E5:3F:A3:1F:A8:E0:C1:6E:C8:B8:BC:89
SHA-256: 36:1E:45:42:C7:E2:EE:6B:AA:4E:F2:48:62:80:FB:D9:22:60:05:CE:46:A8:4C:16:F0:02:C9:2F:CD:DD:C3:D8
```

## Register a certificate in Firebase

1. Open Firebase Console and select **Wicchu**.
2. Open **Project settings → General**.
3. Under **Your apps**, select the Android app `com.wicchu.wicchu`.
4. Select **Add fingerprint**.
5. Add the SHA-1. Add the SHA-256 as well.
6. Open **Authentication → Sign-in method → Google** and confirm that Google is enabled and a support email is selected.
7. Download a fresh `google-services.json`.
8. Replace `android/app/google-services.json` with the downloaded file.

Do not keep downloaded copies such as `google-services (1).json` in the repository or backend directory.

## Rebuild and reinstall

Google configuration is embedded during the Android build. Updating Firebase or the JSON file does not update an already-installed APK.

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Uninstall the previous Wicchu application from the device, install the newly built APK, and try Google Sign-In again.

If the release build uses a dedicated keystore, verify the `release` fingerprint from `signingReport`. A release APK falling back to a debug key must use that debug key's registered fingerprint.

## Google Play builds

When Wicchu is distributed through Google Play, copy the SHA-1 and SHA-256 from **Play Console → Setup → App integrity → App signing key certificate** and register them in the same Firebase Android app. The Play App Signing certificate is normally different from the local upload certificate.

After changing fingerprints, download `google-services.json` again and publish a new build.

## Verification checklist

- The APK package is exactly `com.wicchu.wicchu`.
- The signing certificate SHA-1 is registered in Firebase.
- Google is enabled under Firebase Authentication.
- `android/app/google-services.json` belongs to `wicchu-3ece7` and includes Android and Web OAuth clients.
- The backend `GOOGLE_CLIENT_IDS` contains the Web OAuth client ID.
- A fresh APK was built and installed after configuration changes.
- A successful native login produces `POST /api/auth/google` in backend logs.

If no `/api/auth/google` request appears, continue investigating Android/Firebase configuration. If that request appears and fails, inspect the backend response and configured OAuth audience.
