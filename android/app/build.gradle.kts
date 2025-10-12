plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.hhhh"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // مهم لتفعيل الديسوقرينغ
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.hhhh"
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
    // حدّثنا النسخة المطلوبة هنا ↑ 2.1.4 (يجوز تستخدمي 2.1.5 أيضًا)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // لا تضيفي شيء آخر؛ Flutter/Dart يدير بقية الاعتماديات
}
