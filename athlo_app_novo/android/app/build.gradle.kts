// Não edite este arquivo, ele é gerado pelo Flutter
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.athlo_app_novo"
    compileSdk = flutter.compileSdkVersion

    // 🔧 Aqui forçamos a versão correta do NDK
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src")
            resources.srcDir("src/main/res")
        }
    }

    defaultConfig {
        applicationId = "com.example.athlo_app_novo"
        minSdk = flutter.minSdkVersion   // ✅ Corrigido
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
}

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for release builds.
            // https://developer.android.com/studio/publish/app-signing#gradle-signing
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
