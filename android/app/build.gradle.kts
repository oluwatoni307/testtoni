plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.test"
    compileSdk = flutter.compileSdkVersion
    // Plugins require NDK 27.x; set explicit value to the highest required version
    // (they are backward compatible). This avoids mismatch warnings during CI.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ✅ Use Java 17 for modern plugins
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // ✅ Enable desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.test"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Upgrade to the required version
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
