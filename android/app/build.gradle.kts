import java.util.Properties
import java.io.FileInputStream

// Ключ подписи лежит ВНЕ репозитория: путь и пароли читаются из
// `~/keys/wallet-key.properties`. Без файла сборка идёт отладочным ключом —
// так `flutter run --release` работает на чистой машине, но такой APK нельзя
// поставить поверх настоящего: подписи не совпадут («Приложение не
// установлено», 14.09.2026).
val keyProps = Properties()
val keyPropsFile = file(System.getProperty("user.home") + "/keys/wallet-key.properties")
if (keyPropsFile.exists()) {
    keyProps.load(FileInputStream(keyPropsFile))
}

// Ключи Firebase лежат вне репозитория: пуши от партнёра идут через FCM, а
// `google-services.json` содержит идентификаторы проекта. Без файла плагин не
// применяется вовсе — сборка проходит, а уведомления поднимает запасной путь
// живым каналом пары (`localDeliveryNeeded`). Иначе форк и CI не собрали бы
// приложение ни разу.
val hasFirebase = file("google-services.json").exists()

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

if (hasFirebase) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.togetherly.money"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Требование flutter_local_notifications: без этого сборка падает на
        // проверке метаданных AAR.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.togetherly.money"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyPropsFile.exists()) {
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Свой ключ, если он есть на машине; иначе отладочный, чтобы
            // сборка не падала у того, у кого ключа нет.
            signingConfig = if (keyPropsFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Пуши на Android. Плагин `firebase_messaging` НЕ подключаем намеренно —
    // так же, как в Togetherly: на iOS он перехватывает делегата APNs через
    // swizzling, а FCM нам нужен ровно на Android и ровно за токеном.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
    // Наличие сервисов Google: где их нет, пушей не будет вовсе, и работает
    // запасной путь через живой канал.
    implementation("com.google.android.gms:play-services-base:18.5.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
