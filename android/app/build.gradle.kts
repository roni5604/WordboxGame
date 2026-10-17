import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// חתימה ומזהים לבילד החנות - נקראים מ-android/key.properties (לא ב-git).
// ראו android/key.properties.example ו-docs/STORE_LAUNCH_CHECKLIST.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
fun releaseProp(name: String, fallback: String): String =
    (keystoreProperties.getProperty(name) ?: System.getenv(name) ?: fallback).trim()

// מזהה הבדיקה הרשמי של Google - בטוח לפיתוח, לא מציג פרסומות אמיתיות.
val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"
val admobAppId = releaseProp("ADMOB_APP_ID_ANDROID", admobTestAppId)

android {
    namespace = "com.wordboxil.wordbox_hebrew"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wordboxil.wordbox_hebrew"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // עם android/key.properties - חתימת העלאה אמיתית ל-Google Play.
            // בלי הקובץ - חתימת debug, כדי ש-`flutter run --release` עדיין יעבוד
            // (Google Play ידחה קובץ כזה).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("WARNING: android/key.properties missing - release build is debug-signed and cannot be uploaded to Google Play.")
                signingConfigs.getByName("debug")
            }
            if (admobAppId == admobTestAppId) {
                logger.warn("WARNING: ADMOB_APP_ID_ANDROID not set - the release build uses the AdMob TEST app id.")
            }
        }
    }
}

flutter {
    source = "../.."
}
