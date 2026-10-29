import java.io.StringReader
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ai.fluctio.fluctio_android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs (desugaring is
        // its documented requirement).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ai.fluctio.app"
        // fluctio-android targets modern devices only (owner device is
        // Android 16); 24 still covers 99%+ of potential self-host users.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing: credentials come from android/app/key.properties
    // (gitignored; local builds) or the FLUCTIO_KEYSTORE_PROPS env var
    // (CI, injected from Actions secrets) — never from this file. The
    // keystore itself stays out of git; CI restores it from a secret.
    // Without material the release APK builds unsigned and the workflow's
    // app-release.apk upload fails loudly.
    val keystoreProps = Properties().apply {
        val f = file("key.properties")
        if (f.exists()) {
            f.inputStream().use { load(it) }
        } else {
            System.getenv("FLUCTIO_KEYSTORE_PROPS")?.let { load(StringReader(it)) }
        }
    }

    signingConfigs {
        if (keystoreProps.getProperty("storePassword") != null) {
            create("release") {
                storeFile = file("release.keystore")
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            // Flutter enables R8 shrinking for release builds by default;
            // pin the rules file explicitly so the keeps above are applied.
            isMinifyEnabled = true
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
    // FluctioApplication implements Configuration.Provider. The workmanager
    // plugin declares work-runtime as `implementation`, so it is not on this
    // module's compile classpath without an explicit dependency. Version
    // matches the plugin's (workmanager 0.6.0 → 2.9.0).
    implementation("androidx.work:work-runtime:2.9.0")
}

flutter {
    source = "../.."
}
