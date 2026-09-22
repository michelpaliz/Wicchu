# Facebook Login Requirements

Wicchu's Android Facebook login depends on both the application configuration and the certificate used to sign the APK.

## Meta Android configuration

- Facebook App ID: `1526807682821937`
- Android package name: `com.wicchu.wicchu`
- Default activity: `com.wicchu.wicchu.MainActivity`
- Required permissions: `public_profile` and `email`

The package name and activity must match the values in the Flutter Android project exactly.

## Required key hashes

Meta must contain the Facebook key hash for every certificate used to sign Wicchu. Using the same Git repository does not guarantee the same hash because Android debug keystores are stored on each development computer and are not committed to Git.

The debug hash for the current server build environment is:

```text
CqrfK7r0nIXlP6MfqODBbsi4vIk=
```

If an APK is built on another computer, generate that computer's hash and add it in:

```text
Meta App Dashboard -> App settings -> Basic -> Android -> Key hashes
```

### Linux or macOS

```bash
keytool -exportcert -alias androiddebugkey -keystore "$HOME/.android/debug.keystore" -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

### Windows PowerShell

```powershell
keytool -exportcert -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

After adding a hash, save the Meta configuration, uninstall the old APK, install the newly built APK, and test Facebook login again.

## Production requirement

Production APKs must use a dedicated release keystore instead of the debug keystore. Keep that keystore and its passwords outside Git, configure Android release signing, and register its Facebook key hash in Meta. When distributing through Google Play App Signing, also register the hash derived from Google's app-signing certificate.

## Security

- Never commit the Facebook App Secret or keystore passwords.
- The Facebook App Secret belongs only in the backend environment.
- Do not commit `.jks`, `.keystore`, or `key.properties` files.
