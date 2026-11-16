import java.util.Properties

plugins {
    id("com.android.application")
    // Il plugin Gradle di Flutter va applicato dopo quelli di Android e Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma delle release: android/key.properties (creato dalla CI con i segreti, mai nella repo).
// Senza quel file l'APK release è firmato con la chiave di debug, buona solo per le prove.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "io.github.michelo1927.scrollerstudio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificativo PROVVISORIO di sviluppo (piano §2.3): quello definitivo si decide con l'utente
        // prima di qualsiasi pubblicazione in uno store, perché dopo non si cambia più.
        applicationId = "io.github.michelo1927.scrollerstudio.dev"
        minSdk = 26 // Android 8.0
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
