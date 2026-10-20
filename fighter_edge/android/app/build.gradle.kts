import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // The Crashlytics Gradle plugin (com.google.firebase.crashlytics) is
    // deliberately not applied: 2.8.1 doesn't work at all under this
    // project's Gradle 9.1 (its own Groovy usage throws
    // `groovy/util/XmlSlurper`, and whatever registers its `buildTypes`
    // DSL extension breaks the same way — confirmed by a Kotlin DSL
    // compile error, "Unresolved reference 'firebaseCrashlytics'", not
    // just a task failure). Crash *reporting* is unaffected: it's the
    // firebase_crashlytics Android AAR's own runtime code, wired in by the
    // Flutter plugin mechanism, not by this Gradle plugin. Only automatic
    // ProGuard-mapping upload and build-ID injection are unavailable.
    // Re-add once a Crashlytics Gradle plugin version confirmed compatible
    // with Gradle 9 exists.
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (audit R-2). The upload key comes from
// android/key.properties locally (git-ignored; see key.properties.example)
// or from CI secrets exposed as environment variables. Never commit either.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}

fun signingValue(property: String, env: String): String? =
    (keystoreProperties.getProperty(property) ?: System.getenv(env))
        ?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword,
).all { it != null }

android {
    namespace = "com.fighteredge.fighter_edge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (java.time APIs) requires this.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fighteredge.fighter_edge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Without an upload key, release APKs (local runs, CI smoke
            // builds) fall back to the debug key so `flutter run --release`
            // still works. Store bundles never do: see the guard below.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "Fighter Edge: no release signing configured; release " +
                        "APKs are debug-signed and cannot be uploaded to Play.",
                )
                signingConfigs.getByName("debug")
            }
            // Code and resource shrinking (audit R-11).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}

// A debug-signed App Bundle can't be uploaded to Play. Worse, a tester who
// installs one can't upgrade to a properly signed build without
// uninstalling and losing local data. Fail the store build outright
// instead.
tasks.matching { it.name == "bundleRelease" }.configureEach {
    doFirst {
        if (!hasReleaseSigning) {
            throw GradleException(
                "bundleRelease needs the upload key: set android/key.properties " +
                    "or ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
                    "ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD.",
            )
        }
    }
}
