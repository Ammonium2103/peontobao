plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.jarvis_mobile"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.jarvis_mobile"
        minSdk = 21
        targetSdk = 34
        
        // Cú pháp đúng: versionCode và versionName là thuộc tính (Property)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
        
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Cú pháp đúng cho Kotlin DSL: isMinifyEnabled và isShrinkResources
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
