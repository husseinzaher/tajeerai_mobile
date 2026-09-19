import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Reads a required, non-secret signing property and fails with a clear message
 * when it is missing. Password values are never included in error text.
 */
fun requireKeystoreProperty(
    properties: Properties,
    name: String,
    propertiesFile: java.io.File,
): String {
    val value = properties.getProperty(name)?.trim()

    if (value.isNullOrEmpty()) {
        throw GradleException(
            "Release signing is missing required property '$name' in ${propertiesFile.path}. " +
                "Copy android/key.properties.example to android/key.properties and fill in every field.",
        )
    }

    return value
}

val keystoreProperties = Properties()

// Standard Flutter location: android/key.properties. Also accept android/app/key.properties
// when a keystore lives beside the app module.
val keystorePropertiesFile =
    sequenceOf(rootProject.file("key.properties"), file("key.properties")).firstOrNull { it.exists() }

val releaseSigningConfigured = keystorePropertiesFile != null

if (releaseSigningConfigured) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile!!))
}

android {
    namespace = "com.tajeerai.mobile"

    // Pinned above `flutter.compileSdkVersion`: a plugin in the dependency
    // graph (flutter_secure_storage's AndroidX chain) is compiled against
    // API 37, and Gradle refuses to build an app whose compileSdk is lower
    // than a library it consumes.
    compileSdk = 37

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tajeerai.mobile"

        // 23 is the floor for flutter_secure_storage's EncryptedSharedPreferences
        // and for sqlite3_flutter_libs' bundled library.
        minSdk = maxOf(flutter.minSdkVersion, 23)

        targetSdk = flutter.targetSdkVersion

        // Uses the version code from pubspec.yaml, or --build-name / --build-number
        // when supplied by the Makefile for Play Store releases.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                val propsFile = keystorePropertiesFile!!

                keyAlias = requireKeystoreProperty(keystoreProperties, "keyAlias", propsFile)
                keyPassword = requireKeystoreProperty(keystoreProperties, "keyPassword", propsFile)
                storePassword = requireKeystoreProperty(keystoreProperties, "storePassword", propsFile)

                val storeFilePath = requireKeystoreProperty(keystoreProperties, "storeFile", propsFile)
                // Paths in storeFile are relative to this module (android/app/).
                val resolvedStoreFile = file(storeFilePath)

                if (!resolvedStoreFile.exists()) {
                    throw GradleException(
                        "Release signing: storeFile '$storeFilePath' was not found at " +
                            "${resolvedStoreFile.absolutePath}. " +
                            "For android/app/upload-keystore.jks, set storeFile=upload-keystore.jks in ${propsFile.path}.",
                    )
                }

                storeFile = resolvedStoreFile
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (releaseSigningConfigured) {
                    signingConfigs.getByName("release")
                } else {
                    throw GradleException(
                        "Release builds require android/key.properties with upload keystore settings. " +
                            "Copy android/key.properties.example to android/key.properties, " +
                            "place the .jks file at android/app/upload-keystore.jks, and fill in keyAlias, " +
                            "storeFile, storePassword, and keyPassword.",
                    )
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
