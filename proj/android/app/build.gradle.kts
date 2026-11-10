import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (isReleaseBuildRequested && keystorePropertiesFile.exists()) {
    val requiredProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingProperties = requiredProperties.filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
    if (missingProperties.isNotEmpty()) {
        throw GradleException(
            "Release signing configuration is incomplete. Missing: ${missingProperties.joinToString()}."
        )
    }
    val placeholderProperties = requiredProperties.filter {
        keystoreProperties.getProperty(it).contains("REPLACE_WITH", ignoreCase = true)
    }
    if (placeholderProperties.isNotEmpty()) {
        throw GradleException(
            "Release signing configuration still contains placeholder values for: " +
                "${placeholderProperties.joinToString()}. Replace them in android/key.properties with the original keystore credentials."
        )
    }

    val keystoreFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
    if (!keystoreFile.isFile) {
        throw GradleException("Release keystore file does not exist: ${keystoreFile.path}")
    }

}

android {
    namespace = "com.pigworld"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pigworld"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            providers.gradleProperty("GOOGLE_MAPS_API_KEY").orNull
                ?: System.getenv("GOOGLE_MAPS_API_KEY")
                ?: ""
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.create("release") {
                    storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                }
            } else if (isReleaseBuildRequested) {
                throw GradleException(
                    "Release signing is not configured. Add your own android/key.properties and upload keystore."
                )
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
