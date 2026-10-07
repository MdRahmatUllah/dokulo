import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key (DK-0015): the owner creates and keeps it, never in the repo.
// android/key.properties (gitignored) names it; without that file, release
// builds are signed with the debug key so `flutter run --release` still works.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "app.dokulo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The owner's decision (2026-10-07): app.dokulo, plus .dev and .staging.
        applicationId = "app.dokulo"
        minSdk = 26 // Android 8.0: camera/HEIC support and model performance (DK-0002)
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml's version: "1.0.0+100" → versionName 1.0.0, versionCode 100.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // dev, staging and prod install side by side (DK-0015). The default flavor
    // is set in pubspec.yaml (flutter: default-flavor), so a plain `flutter run`
    // builds dev.
    buildFeatures {
        resValues = true // the flavors' app_name
    }
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Dokulo Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Dokulo Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Dokulo")
        }
    }

    signingConfigs {
        if (keyProperties.containsKey("storeFile")) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
