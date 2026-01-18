import java.io.FileInputStream
import java.util.*

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.habitera.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.habitera.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Load signing configuration from key.properties
    signingConfigs {
        create("release") {
            val keyPropertiesFile = file("../key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties()
                keyProperties.load(FileInputStream(keyPropertiesFile))
                
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = file("../${keyProperties.getProperty("storeFile")}")
                storePassword = keyProperties.getProperty("storePassword")
            } else {
                println("WARNING: key.properties not found. Using debug signing.")
                // Fallback to debug signing if key.properties doesn't exist
                keyAlias = "androiddebugkey"
                keyPassword = "android"
                storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
                storePassword = "android"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Disable minification to prevent flutter_local_notifications issues
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
