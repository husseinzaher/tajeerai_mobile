import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

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

// Whether this invocation is actually assembling a release. This file is
// evaluated at configuration time, for every build, so a release-only check
// that throws here would take the debug build down with it.
val assemblingRelease = gradle.startParameter.taskNames.any { it.contains("elease") }

val requiredKeystoreProperties = listOf("keyAlias", "keyPassword", "storePassword", "storeFile")

// Three cases, and only the middle one is a failure:
//
// - no key.properties at all -- legitimate. A contributor without the upload
//   keystore still builds and runs debug;
// - key.properties present but incomplete -- a mistake, not a request for an
//   unsigned build. Left to fall through it produces an APK the device rejects
//   with INSTALL_PARSE_FAILED_NO_CERTIFICATES, an error that names nothing.
//   Say which property is missing, when a release is what was asked for;
// - complete -- sign with it.
val releaseSigningConfigured =
    keystorePropertiesFile?.let { propertiesFile ->
        keystoreProperties.load(FileInputStream(propertiesFile))

        val complete =
            requiredKeystoreProperties.all { !keystoreProperties.getProperty(it).isNullOrBlank() }

        if (!complete && assemblingRelease) {
            requiredKeystoreProperties.forEach { name ->
                requireKeystoreProperty(keystoreProperties, name, propertiesFile)
            }
        }

        complete
    } == true

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
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
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
