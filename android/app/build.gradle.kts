import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La clé de signature de la version publiée. Elle ne vit pas dans le dépôt :
// `android/key.properties` et le fichier `.jks` sont ignorés par git
// (`android/.gitignore`). Voir `android/key.properties.example` pour les
// créer.
//
// Signer une release avec la clé de debug — ce que faisait ce fichier —
// donne un APK que n'importe qui peut re-signer et republier sous le même
// nom : la clé de debug est la même sur toutes les machines Flutter.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

// Sans clé, une release échoue — au lieu de partir signée avec la clé de
// debug. La vérification n'a lieu que si une tâche « Release » est
// demandée : `flutter run` et les builds de debug n'en ont pas besoin.
gradle.taskGraph.whenReady {
    val construitUneRelease = allTasks.any { it.name.contains("Release") }
    if (construitUneRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties est introuvable : la version publiée doit " +
                "être signée avec la clé de MTC, jamais avec la clé de debug. " +
                "Voir android/key.properties.example."
        )
    }
}

android {
    namespace = "com.mtc.mtc_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mtc.mtc_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
