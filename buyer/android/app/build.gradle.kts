import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.pigworld.market"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pigworld.market"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                val requiredProperties =
                    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                val missingProperties = requiredProperties.filter {
                    keystoreProperties.getProperty(it).isNullOrBlank()
                }
                if (missingProperties.isNotEmpty()) {
                    throw GradleException(
                        "Release signing configuration is incomplete. Missing: " +
                            missingProperties.joinToString()
                    )
                }
                val placeholderProperties = requiredProperties.filter {
                    keystoreProperties.getProperty(it)
                        .contains("REPLACE_WITH", ignoreCase = true)
                }
                if (placeholderProperties.isNotEmpty()) {
                    throw GradleException(
                        "Release signing configuration still contains placeholders for: " +
                            "${placeholderProperties.joinToString()}. Replace them in android/key.properties."
                    )
                }
                val keystoreFile = rootProject.file(
                    keystoreProperties.getProperty("storeFile")
                )
                if (!keystoreFile.isFile) {
                    throw GradleException(
                        "Release keystore file does not exist: ${keystoreFile.path}"
                    )
                }
                signingConfigs.create("release") {
                    storeFile = keystoreFile
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                }
            } else if (isReleaseBuildRequested) {
                throw GradleException(
                    "Release signing is not configured. Add android/key.properties and your " +
                        "Play upload keystore. Do not use the debug signing key for Play uploads."
                )
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
