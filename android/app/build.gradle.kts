import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystoreProperties = Properties()
val releaseKeystoreFile = rootProject.file("key.properties")
if (releaseKeystoreFile.exists()) {
    releaseKeystoreFile.inputStream().use(releaseKeystoreProperties::load)
}

android {
    namespace = "com.wicchu.wicchu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wicchu.wicchu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "facebook_app_id", providers.gradleProperty("FACEBOOK_APP_ID").orElse("1526807682821937").get())
        resValue("string", "facebook_client_token", providers.gradleProperty("FACEBOOK_CLIENT_TOKEN").orElse("391b03713866b79cc92759b742a32825").get())
    }

    signingConfigs {
        if (releaseKeystoreFile.exists()) {
            create("release") {
                fun requiredProperty(name: String): String =
                    requireNotNull(releaseKeystoreProperties.getProperty(name)) {
                        "Missing $name in android/key.properties"
                    }

                keyAlias = requiredProperty("keyAlias")
                keyPassword = requiredProperty("keyPassword")
                storeFile = file(requiredProperty("storeFile"))
                storePassword = requiredProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Local preview builds use the debug key until a release key is configured.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
